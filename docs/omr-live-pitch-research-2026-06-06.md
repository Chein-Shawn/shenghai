# OMR 與 Live Microphone Pitch Tracking 研究筆記｜2026-06-06

## 結論

聲海 MVP 不應自研完整 OMR 模型。第一版應採用 `PDF / image -> Audiveris or OMR service -> MusicXML -> ScoreDocument -> MIDI/playback`，並把校驗、手動修正、播放驗證做成產品核心。

Live microphone pitch tracking 則可先用 YIN 類即時基線做 monophonic vocal tracking，再用 smoothing/confidence 避免誤判；後續可替換為 pYIN、CREPE、PESTO 或 Core ML 模型。

## 市面產品觀察

### PlayScore 2

- 原文短句："Mute any combination of staves."
- 原文短句："Play whole PDF scores and export as MusicXML."
- 應用到聲海：合唱練習的核心不是只辨識音符，而是能選聲部、靜音其他聲部、調速度、循環段落。
- MVP 策略：MusicXML 匯入後先做聲部分離播放與 MIDI 匯出，OMR 可以先是外部 pipeline。

Source: https://www.playscore.co/

### Newzik LiveScores

- 原文短句："LiveScores is our AI-powered OMR technology."
- 原文短句："export to MusicXML/MIDI"
- 應用到聲海：PDF 轉互動樂譜後，價值在 guided playback、section navigation、transposition、MusicXML/MIDI export。
- MVP 策略：聲海要把 OMR 結果包進 ScoreDocument，保留小節導航、聲部、校正狀態。

Source: https://newzik.com/en/ai

### StaveWave

- 原文短句："MusicXML plus confidence notes and an audit log"
- 原文短句："No. The conversion page keeps uncertain measures"
- 應用到聲海：OMR 不要裝作 100% 正確，應明確顯示疑似錯誤小節與需要校正處。
- MVP 策略：未來 ScoreDocument 應加入 `recognitionConfidence`、`validationWarnings`、`needsReviewMeasureIDs`。

Source: https://stavewave.com/

### Singscope

- 原文短句："Computes and draws pitch graphs in real-time"
- 原文短句："It can not handle more than one singing voice"
- 應用到聲海：即時音高回饋應先限制為單人單旋律輸入；合唱環境應要求耳機或獨唱錄音。
- MVP 策略：Practice mode 標註「solo voice tracking」，避免把伴奏/多人聲誤判成使用者音高。

Source: https://apps.apple.com/sc/app/singscope/id944309175

## 論文與技術重點

### OMR Survey: State of the Art and Major Challenges

- 原文短句："transcribing sheet music into a machine-readable format"
- 原文短句："The usual output formats are MusicXML and MIDI."
- 原文短句："space for improvement in all stages"
- 應用到聲海：OMR 是 pipeline，不是單一模型。需拆為 image preprocessing、symbol recognition、semantic reconstruction、notation model。
- MVP 策略：目前實作 `OMRPipelinePlan`，用 stage/status/note 追蹤 OMR 卡點。

Source: https://www.tenor-conference.org/proceedings/2020/23_Shatri_tenor20.pdf

### Practical End-to-End OMR / Linearized MusicXML

- 原文短句："Linearized MusicXML"
- 原文短句："compatibility with the industry-standard MusicXML"
- 應用到聲海：深度學習 OMR 若要自研，輸出仍應靠近 MusicXML，不要發明難以交換的格式。
- MVP 策略：保留 MusicXML 為主格式；ScoreDocument 只做 app wrapper。

Source: https://arxiv.org/abs/2403.13763

### CREPE

- 原文短句："operates directly on the time-domain waveform"
- 原文短句："performing equally or better than pYIN"
- 應用到聲海：CREPE 適合作為未來高準確度 pitch tracker，但 MVP 可先用較輕的 YIN baseline。
- MVP 策略：`PitchTracking` protocol 已讓 YIN/CREPE/pYIN 可替換。

Source: https://arxiv.org/abs/1802.06182

### pYIN / Singing Pitch Comparison

- 原文短句："adapted to singing voice analysis"
- 原文短句："detect voicing boundaries"
- 應用到聲海：唱歌不是一般 speech pitch tracking，需要處理 vibrato、換聲區、voiced/unvoiced 邊界。
- MVP 策略：即時 UI 必須顯示 confidence；低信心不要畫紅色錯誤。

Sources:
- https://www.eecs.qmul.ac.uk/~simond/pub/2014/MauchDixon-PYIN-ICASSP2014.pdf
- https://arxiv.org/abs/1912.12609

### Smart-Median Pitch Contour Smoothing

- 原文短句："incorrect pitch estimation often happens"
- 原文短句："smoothing singing pitch contours"
- 應用到聲海：即時偵測常出現 octave jump 或短暫錯點，應先 smoothing 再給使用者視覺回饋。
- MVP 策略：已實作 `MedianPitchContourSmoother` 並接到 live microphone prototype。

Source: https://www.mdpi.com/2076-3417/12/14/7026

## 已落地到程式碼

- `OMRPipeline.swift`: OMR stage/status plan and Audiveris command builder.
- `YINPitchTracker.swift`: YIN-style monophonic pitch tracker.
- `LivePitchCaptureService.swift`: AVAudioEngine microphone tap + YIN pitch tracking.
- `PracticeView.swift`: live microphone prototype UI.
- `VocalDiveCoreTests.swift`: synthetic A4 pitch detection and Audiveris command tests.

## 下一步

1. 安裝 Audiveris release，跑合法測試譜 PDF/image 到 MusicXML。
2. 增加 OMR output validator：小節拍數、空小節、超出 vocal range、無法播放音符。
3. 把 live pitch tracking 的 sample 對齊 ScoreDocument target pitch timeline。
4. 把低 confidence / sharp / flat 畫成 practice feedback overlay。
5. 研究 CREPE/Basic Pitch/PESTO 是否能以 Core ML 或 server fallback 接入。
