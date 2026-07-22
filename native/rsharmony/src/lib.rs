// SPDX-License-Identifier: AGPL-3.0-or-later

use std::collections::HashMap;
use std::mem::ManuallyDrop;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

pub const STATUS_OK: i32 = 0;
pub const STATUS_INVALID_ARGUMENT: i32 = 1;
pub const STATUS_HANDLE_NOT_FOUND: i32 = 2;
pub const STATUS_BACKEND_ERROR: i32 = 3;
pub const STATUS_NATIVE_FATAL: i32 = 4;

#[repr(C)]
#[derive(Debug)]
pub struct AnkiBuffer {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}

impl AnkiBuffer {
    fn from_vec(bytes: Vec<u8>) -> Self {
        if bytes.is_empty() {
            return Self::default();
        }
        let mut bytes = ManuallyDrop::new(bytes);
        Self {
            ptr: bytes.as_mut_ptr(),
            len: bytes.len(),
            cap: bytes.capacity(),
        }
    }
}

impl Default for AnkiBuffer {
    fn default() -> Self {
        Self {
            ptr: ptr::null_mut(),
            len: 0,
            cap: 0,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum BackendFailure {
    HandleNotFound,
    Poisoned,
    Backend(Vec<u8>),
}

pub trait RawBackend: Send + 'static {
    fn run_method_raw(
        &mut self,
        service: u32,
        method: u32,
        input: &[u8],
    ) -> Result<Vec<u8>, BackendFailure>;
}

type SharedBackend = Arc<Mutex<Box<dyn RawBackend>>>;

pub struct BackendRegistry {
    next_handle: AtomicU32,
    backends: Mutex<HashMap<u32, SharedBackend>>,
}

impl BackendRegistry {
    pub fn new() -> Self {
        Self {
            next_handle: AtomicU32::new(1),
            backends: Mutex::new(HashMap::new()),
        }
    }

    pub fn insert<B: RawBackend>(&self, backend: B) -> u32 {
        // 锁中毒时返回无效句柄 0，由 FFI 层转成错误码，绝不在 FFI 边界 panic。
        let mut backends = match self.backends.lock() {
            Ok(backends) => backends,
            Err(_) => return 0,
        };
        // 句柄 0 保留为“无效”，可用句柄共 u32::MAX 个。耗尽时直接失败，
        // 避免 next_handle 回绕后在已满的表中无限扫描。
        if backends.len() >= u32::MAX as usize {
            return 0;
        }
        loop {
            let handle = self.next_handle.fetch_add(1, Ordering::Relaxed);
            if handle != 0 && !backends.contains_key(&handle) {
                backends.insert(handle, Arc::new(Mutex::new(Box::new(backend))));
                return handle;
            }
        }
    }

    pub fn call(
        &self,
        handle: u32,
        service: u32,
        method: u32,
        input: &[u8],
    ) -> Result<Vec<u8>, BackendFailure> {
        let backend = self
            .backends
            .lock()
            .map_err(|_| BackendFailure::Poisoned)?
            .get(&handle)
            .cloned()
            .ok_or(BackendFailure::HandleNotFound)?;
        let result = backend
            .lock()
            .map_err(|_| BackendFailure::Poisoned)?
            .run_method_raw(service, method, input);
        result
    }

    pub fn close(&self, handle: u32) -> bool {
        self.backends
            .lock()
            .map(|mut backends| backends.remove(&handle).is_some())
            .unwrap_or(false)
    }
}

impl Default for BackendRegistry {
    fn default() -> Self {
        Self::new()
    }
}

static BACKENDS: OnceLock<BackendRegistry> = OnceLock::new();

fn global_backends() -> &'static BackendRegistry {
    BACKENDS.get_or_init(BackendRegistry::new)
}

unsafe fn set_buffer(target: *mut AnkiBuffer, value: Vec<u8>) {
    if !target.is_null() {
        unsafe { target.write(AnkiBuffer::from_vec(value)) };
    }
}

unsafe fn set_error(target: *mut AnkiBuffer, message: &str) {
    unsafe { set_buffer(target, message.as_bytes().to_vec()) };
}

unsafe fn call_with_registry(
    registry: &BackendRegistry,
    handle: u32,
    service: u32,
    method: u32,
    input_ptr: *const u8,
    input_len: usize,
    out_result: *mut AnkiBuffer,
    out_error: *mut AnkiBuffer,
) -> i32 {
    if out_result.is_null() || out_error.is_null() {
        return STATUS_INVALID_ARGUMENT;
    }
    unsafe {
        out_result.write(AnkiBuffer::default());
        out_error.write(AnkiBuffer::default());
    }
    if input_len > 0 && input_ptr.is_null() {
        unsafe { set_error(out_error, "input pointer is null") };
        return STATUS_INVALID_ARGUMENT;
    }

    let input = if input_len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
    };

    match catch_unwind(AssertUnwindSafe(|| {
        registry.call(handle, service, method, input)
    })) {
        Ok(Ok(output)) => {
            unsafe { set_buffer(out_result, output) };
            STATUS_OK
        }
        Ok(Err(BackendFailure::HandleNotFound)) => {
            unsafe { set_error(out_error, "backend handle not found") };
            STATUS_HANDLE_NOT_FOUND
        }
        Ok(Err(BackendFailure::Poisoned)) => {
            unsafe { set_error(out_error, "native backend state is unavailable") };
            STATUS_NATIVE_FATAL
        }
        Ok(Err(BackendFailure::Backend(message))) => {
            unsafe { set_buffer(out_error, message) };
            STATUS_BACKEND_ERROR
        }
        Err(_) => {
            unsafe { set_error(out_error, "native backend panicked") };
            STATUS_NATIVE_FATAL
        }
    }
}

#[cfg(feature = "anki-core")]
struct AnkiBackend(anki::backend::Backend);

#[cfg(feature = "anki-core")]
impl RawBackend for AnkiBackend {
    fn run_method_raw(
        &mut self,
        service: u32,
        method: u32,
        input: &[u8],
    ) -> Result<Vec<u8>, BackendFailure> {
        self.0
            .run_service_method(service, method, input)
            .map_err(BackendFailure::Backend)
    }
}

#[no_mangle]
pub unsafe extern "C" fn anki_backend_open(
    init_ptr: *const u8,
    init_len: usize,
    out_handle: *mut u32,
    out_error: *mut AnkiBuffer,
) -> i32 {
    if out_handle.is_null() || out_error.is_null() {
        return STATUS_INVALID_ARGUMENT;
    }
    unsafe {
        out_handle.write(0);
        out_error.write(AnkiBuffer::default());
    }
    if init_len > 0 && init_ptr.is_null() {
        unsafe { set_error(out_error, "init pointer is null") };
        return STATUS_INVALID_ARGUMENT;
    }
    let init = if init_len == 0 {
        &[]
    } else {
        unsafe { std::slice::from_raw_parts(init_ptr, init_len) }
    };

    #[cfg(feature = "anki-core")]
    {
        return match catch_unwind(AssertUnwindSafe(|| anki::backend::init_backend(init))) {
            Ok(Ok(backend)) => {
                // 注册也可能 panic（如内部锁状态异常），同样必须关在 catch_unwind 里。
                let registered = catch_unwind(AssertUnwindSafe(|| {
                    global_backends().insert(AnkiBackend(backend))
                }));
                match registered {
                    Ok(handle) if handle != 0 => {
                        unsafe { out_handle.write(handle) };
                        STATUS_OK
                    }
                    Ok(_) => {
                        unsafe { set_error(out_error, "native backend registry is unavailable") };
                        STATUS_NATIVE_FATAL
                    }
                    Err(_) => {
                        unsafe {
                            set_error(out_error, "native backend panicked during registration")
                        };
                        STATUS_NATIVE_FATAL
                    }
                }
            }
            Ok(Err(message)) => {
                unsafe { set_error(out_error, &message) };
                STATUS_BACKEND_ERROR
            }
            Err(_) => {
                unsafe { set_error(out_error, "native backend panicked during initialization") };
                STATUS_NATIVE_FATAL
            }
        };
    }

    #[cfg(not(feature = "anki-core"))]
    {
        let _ = init;
        unsafe { set_error(out_error, "anki-core feature is disabled") };
        STATUS_BACKEND_ERROR
    }
}

#[no_mangle]
pub unsafe extern "C" fn anki_backend_call(
    handle: u32,
    service: u32,
    method: u32,
    input_ptr: *const u8,
    input_len: usize,
    out_result: *mut AnkiBuffer,
    out_error: *mut AnkiBuffer,
) -> i32 {
    unsafe {
        call_with_registry(
            global_backends(),
            handle,
            service,
            method,
            input_ptr,
            input_len,
            out_result,
            out_error,
        )
    }
}

#[no_mangle]
pub extern "C" fn anki_backend_close(handle: u32) -> i32 {
    if global_backends().close(handle) {
        STATUS_OK
    } else {
        STATUS_HANDLE_NOT_FOUND
    }
}

#[no_mangle]
pub unsafe extern "C" fn anki_buffer_free(buffer: AnkiBuffer) {
    if !buffer.ptr.is_null() {
        unsafe {
            drop(Vec::from_raw_parts(buffer.ptr, buffer.len, buffer.cap));
        }
    }
}

#[cfg(test)]
mod ffi_tests {
    use super::*;

    struct PanicBackend;

    impl RawBackend for PanicBackend {
        fn run_method_raw(
            &mut self,
            _service: u32,
            _method: u32,
            _input: &[u8],
        ) -> Result<Vec<u8>, BackendFailure> {
            panic!("card content must never escape through a panic")
        }
    }

    fn buffer_text(buffer: &AnkiBuffer) -> String {
        if buffer.ptr.is_null() || buffer.len == 0 {
            return String::new();
        }
        let bytes = unsafe { std::slice::from_raw_parts(buffer.ptr, buffer.len) };
        String::from_utf8_lossy(bytes).into_owned()
    }

    #[test]
    fn ffi_rejects_a_null_input_with_nonzero_length() {
        let registry = BackendRegistry::new();
        let mut output = AnkiBuffer::default();
        let mut error = AnkiBuffer::default();

        let status = unsafe {
            call_with_registry(
                &registry,
                1,
                1,
                1,
                std::ptr::null(),
                4,
                &mut output,
                &mut error,
            )
        };

        assert_eq!(status, STATUS_INVALID_ARGUMENT);
        assert_eq!(buffer_text(&error), "input pointer is null");
        unsafe { anki_buffer_free(error) };
    }

    #[test]
    fn ffi_returns_owned_output_and_reports_missing_handles() {
        let registry = BackendRegistry::new();
        let mut output = AnkiBuffer::default();
        let mut error = AnkiBuffer::default();

        let status = unsafe {
            call_with_registry(
                &registry,
                42,
                1,
                1,
                std::ptr::null(),
                0,
                &mut output,
                &mut error,
            )
        };

        assert_eq!(status, STATUS_HANDLE_NOT_FOUND);
        assert_eq!(buffer_text(&error), "backend handle not found");
        unsafe { anki_buffer_free(error) };
    }

    #[test]
    fn ffi_contains_panics_and_returns_a_sanitized_error() {
        let registry = BackendRegistry::new();
        let handle = registry.insert(PanicBackend);
        let mut output = AnkiBuffer::default();
        let mut error = AnkiBuffer::default();

        let status = unsafe {
            call_with_registry(
                &registry,
                handle,
                1,
                1,
                std::ptr::null(),
                0,
                &mut output,
                &mut error,
            )
        };

        assert_eq!(status, STATUS_NATIVE_FATAL);
        assert_eq!(buffer_text(&error), "native backend panicked");
        unsafe { anki_buffer_free(error) };
    }

    #[test]
    fn insert_returns_zero_when_the_registry_lock_is_poisoned() {
        let registry = BackendRegistry::new();
        let poisoned = catch_unwind(AssertUnwindSafe(|| {
            let _guard = registry.backends.lock().unwrap();
            panic!("poison the registry mutex");
        }));
        assert!(poisoned.is_err());

        assert_eq!(registry.insert(PanicBackend), 0);
    }

    #[cfg(feature = "anki-core")]
    #[test]
    fn ffi_opens_and_closes_an_anki_backend_from_default_proto() {
        let mut handle = 0_u32;
        let mut error = AnkiBuffer::default();

        let status = unsafe {
            anki_backend_open(std::ptr::null(), 0, &mut handle, &mut error)
        };

        assert_eq!(status, STATUS_OK, "{}", buffer_text(&error));
        assert_ne!(handle, 0);
        assert_eq!(anki_backend_close(handle), STATUS_OK);
        unsafe { anki_buffer_free(error) };
    }
}
