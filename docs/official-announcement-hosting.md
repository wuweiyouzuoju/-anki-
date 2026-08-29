# 官方公告静态托管指南

生产地址：
`https://4001784660.cdn.123clouddisk.com/4001784660/jidecards/announcement.json`

应用只读取公开 JSON；123 云盘 Client ID、Client Secret、Token 只能用于开发电脑或受控发布环境。

## 发布

1. 从 `hosting/announcement.json` 复制工作文件。
2. 发布公告时把 `announcement` 改为完整对象，并为每条新公告生成新 ID。
3. `startsAt` 和 `expiresAt` 使用带时区的 ISO 8601；`actionUrl` 为空或为 HTTPS。
4. 上传到 123 云盘 `/jidecards/announcement.json`，保持父目录直链已启用。
5. 用下面命令验证公开内容；成功后才视为发布完成。

```powershell
$announcementUrl='https://4001784660.cdn.123clouddisk.com/4001784660/jidecards/announcement.json?v=' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$response=Invoke-WebRequest -Uri $announcementUrl -TimeoutSec 20
if ($response.StatusCode -ne 200) { throw "announcement HTTP $($response.StatusCode)" }
$document=$response.Content | ConvertFrom-Json
if ($document.schemaVersion -ne 1) { throw 'announcement schema mismatch' }
$document | ConvertTo-Json -Depth 4
```

## 停用与回滚

发布 `{ "schemaVersion": 1, "announcement": null }` 可立即停用。若回滚到以前的公告文件，旧 ID 已在用户设备的最近 32 项记录中，不会重复展示；需要重新通知时必须发布新 ID。

## 完整公告示例

```json
{
  "schemaVersion": 1,
  "announcement": {
    "id": "20260829-01",
    "enabled": true,
    "titleZh": "官方公告",
    "contentZh": "记得闪卡云端牌组服务现已开放。",
    "titleEn": "Official announcement",
    "contentEn": "Cloud decks are now available.",
    "publishedAt": "2026-08-29T18:00:00+08:00",
    "startsAt": "2026-08-29T18:00:00+08:00",
    "expiresAt": "2026-09-30T23:59:59+08:00",
    "minimumAppVersion": "2.0.0",
    "maximumAppVersion": "",
    "actionUrl": ""
  }
}
```
