# Codex 實作工作日誌｜2026-06-05

## 本次追加原則

- 僅追加本段內容，不改動前方人工規劃內容。
- 不刪除、不覆蓋既有工作日誌 log。
- 本段用來記錄 Codex 依照聲海計劃開始實作的結果、限制與下一步。

## 樂譜格式研究結論

第一版不從零開發主要樂譜格式，而是採用市面標準格式與聲海自家 wrapper：

- MusicXML / .mxl：主要樂譜交換格式，用於 OMR 後輸出與跨軟體交換。
- VocalDive ScoreDocument JSON：聲海內部專案檔，保存 OMR 結果、手動校正、反覆記號展開、小節播放順序、同步點與練習紀錄。
- MIDI：播放中介格式，用於把樂譜轉成可聽的事件時間軸。
- WAV / AAC：展示或輸出音檔格式。
- SMuFL：未來樂譜符號字型與渲染標準。
- MEI：暫不納入 MVP 主線，留給學術或古樂進階研究。

## OMR 到播放 Pipeline

PDF / 圖片樂譜 → 影像前處理 → Audiveris OMR baseline → MusicXML / MXL → MusicXML Parser → VocalDive ScoreDocument → 反覆記號展開 → 手動校正音高/小節 → MIDI Event Timeline → 音源合成播放 → WAV / AAC 或 app 內播放。

## 本機實作進度

已在本機建立專案資料夾：

```text
/Users/shawn/Documents/Codex/vocaldive
```

已建立結構：

- README.md
- docs/architecture.md
- docs/format-research.md
- docs/worklog.md
- docs/google-doc-appendix-2026-06-05.md
- research/omr/musicxml_to_scoredocument.py
- samples/musicxml/twinkle.musicxml
- samples/musicxml/twinkle.scoredocument.json
- samples/audio/twinkle.mid
- ios-app/

已完成 prototype：

```text
MusicXML -> ScoreDocument JSON -> MIDI
```

測試樣本 `twinkle.musicxml` 已成功解析為 ScoreDocument，並輸出 `twinkle.mid`。這證明在 OMR 產生 MusicXML 之後，聲海可以把樂譜資料轉成可播放 MIDI 事件。

## GitHub 備份狀態

已透過瀏覽器建立 private GitHub repo：

https://github.com/Chein-Shawn/vocaldive

目前狀態：repo 已建立，但本機 `git push` 因 private repo HTTPS 認證不足失敗；GitHub connector 也尚未被授權存取這個新 private repo。

需要下一步權限：

- 讓 GitHub App / connector 存取 `Chein-Shawn/vocaldive`，或
- 在本機 Git 設定可推送 private repo 的 GitHub 認證，或
- 手動在 GitHub repo 頁面完成 push instructions。

## 工具檢查

已確認：

- Java 已安裝。
- Git 已安裝。
- Audiveris 尚未安裝。
- MuseScore CLI 尚未安裝。
- FluidSynth 尚未安裝。

因此目前已完成 MusicXML 之後的 prototype；真正 PDF/圖片 OMR 需要安裝 Audiveris 或取得可執行 OMR 工具。

## 下一步

1. 授權 GitHub connector 或本機 Git push，完成遠端備份。
2. 安裝 Audiveris，開始 PDF/圖片 → MusicXML 測試。
3. 準備 1-3 份合法可測試簡單樂譜。
4. 記錄 OMR 成功率、錯誤類型、是否能辨識小節/音高/節奏/反覆記號。
5. 將 ScoreDocument parser 逐步接入 Xcode multiplatform app。
