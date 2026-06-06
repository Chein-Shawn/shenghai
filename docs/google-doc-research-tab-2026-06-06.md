# 研究與演算法筆記｜聲海計畫

> 建議放在 Google Doc 的獨立文件分頁：`研究與演算法筆記`。
> 目的：把學術/技術研究轉成聲海 MVP 可用的產品能力。
> 註：原文因著作權只保留短摘句；真正用於計畫書的重點以中文改寫整理。

## 1. 即時視覺回饋與聲樂訓練

### Real-Time Visual Feedback in Singing Pedagogy

- 來源：Lã and Fiuza, 2022, Applied Sciences.
- 原文開頭摘句："the voice is invisible to the eye"; "evidence-based practices in voice education"
- 研究重點：聲音本身不可視，所以即時視覺化可以讓學生看見呼吸、聲帶振動、音高、強度、共鳴等資訊。
- 可應用突破：聲海可以把「聽不見自己錯在哪裡」改成「看得見自己偏在哪裡」。這讓 app 不只是 tuner，而是把聲樂老師常說的抽象語言，例如偏高、偏低、氣息不穩，轉成圖像化的練習證據。
- 聲海用法：把使用者唱的 pitch contour 疊在譜面旋律上，讓音準偏差變成可見資訊。
- MVP 影響：練習模式不要只顯示「對/錯」，要顯示「偏高/偏低/偏差多少 cents」。
- Link: https://www.mdpi.com/2076-3417/12/21/10781

### Concurrent Visual Feedback and Adult Singing Accuracy

- 來源：Paney and Tharp, 2021, Psychology of Music.
- 原文開頭摘句："Singing more often, particularly with objective, concurrent feedback"
- 研究重點：10 週實驗中，成人非音樂主修者有進步；重點不只是即時回饋本身，而是客觀回饋加上持續練習。
- 可應用突破：聲海的核心不該只是單次評分，而是像 Strava 一樣把練習累積成長期紀錄。使用者每次練習都留下音準、穩定度、聲部、樂句的客觀資料，暑假內測時就可以展示「有沒有進步」。
- 聲海用法：把 app 定位成「練習記錄 + 客觀音準回饋」，而不是一次性的評分器。
- MVP 影響：優先做練習 streak、每首歌/每聲部的音準趨勢，而不只是單次分數。
- Link: https://journals.sagepub.com/doi/abs/10.1177/0305735619854534

### Visual and Auditory Feedback for Poor-Pitch Remediation

- 來源：Berglin, Pfordresher, and Demorest, 2022, Psychology of Music.
- 原文開頭摘句："Visual feedback may facilitate accuracy"; "singing is a learned skill"
- 研究重點：短時間訓練中，視覺回饋組的改善較明顯，尤其是 4-note melodies，而不只是單音 matching。
- 可應用突破：這篇最接近聲海的產品假設：唱準不是天賦二分法，而是可以被訓練的技能。聲海應該支援「短樂句」而不是只做單音，因為合唱過譜真正需要的是連續旋律與音程關係。
- 聲海用法：不要只做單音校準；要支援短樂句、音程、旋律片段練習。
- MVP 影響：新增「小節/短句練習」概念：使用者選 1-4 小節反覆練，app 顯示旋律線與偏差。
- Link: https://journals.sagepub.com/doi/abs/10.1177/03057356211026730

## 2. 歌聲 Pitch Tracking / F0 偵測

### CREPE: Deep Learning Pitch Estimation

- 來源：Kim et al., 2018, ICASSP/arXiv.
- 原文開頭摘句："operates directly on the time-domain waveform"; "open-source Python module"
- 研究重點：CREPE 用 CNN 直接從 waveform 做 pitch tracking，表現可達或超過 pYIN，且有 open-source Python module。
- 可應用突破：聲海可以先用 CREPE 作為研究 baseline，不必一開始自己發明 pitch detector。架構上只要把 pitch tracking 做成可替換 protocol，未來就能從 Python research pipeline 過渡到 Core ML 或 Apple 原生即時偵測。
- 聲海用法：研究階段可用 CREPE 做 reference pitch tracker；Apple app 端再評估 Core ML 轉換或改用輕量 DSP。
- MVP 影響：先設計抽象介面 `PitchTracker`，讓 YIN/pYIN/CREPE/Basic Pitch 可以替換。
- Link: https://arxiv.org/abs/1802.06182

### Comparative Study of Pitch Extraction Algorithms on Singing Sounds

- 來源：Babacan et al., 2019, arXiv.
- 原文開頭摘句："adapted to singing voice analysis"; "comparative evaluation"
- 研究重點：唱歌和語音不同；演算法要考慮 singer category、laryngeal mechanism、reverberation 等條件。
- 可應用突破：聲海不能直接把語音辨識或一般 tuner 的邏輯搬來用，因為歌聲有更寬的音域、延音、vibrato、聲部差異與環境殘響。這支持 MVP 一開始就保留聲部/音域設定，並建立不同聲部的測試資料。
- 聲海用法：不要假設所有聲音都能用同一組參數；未來要依聲部、音域、環境噪音調整 pitch tracker。
- MVP 影響：在設定裡保留「聲部/音域」欄位，並在測試資料中分男聲、女聲、不同音域。
- Link: https://arxiv.org/abs/1912.12609

### Real-Time Monophonic Singing Pitch Detection

- 來源：Faghih and Timoney, 2022, preprint.
- 原文開頭摘句："a perfect real-time pitch detector algorithm for singing is not yet available"
- 研究重點：即時歌聲 pitch detection 仍會受 window size、hop size、性別、音程、速度、後處理影響。
- 可應用突破：聲海的回饋設計必須承認演算法不確定性。當訊號不穩、背景太吵或 pitch tracker 信心不足時，app 應顯示 low confidence，而不是直接把使用者標紅判錯。
- 聲海用法：產品上要避免過度自信；可以顯示 confidence 或「需要重唱/訊號不穩」狀態。
- MVP 影響：音高偏差標記不要只有紅色錯誤；要有 low-confidence 狀態，避免誤傷使用者信心。
- Link: https://www.researchgate.net/publication/361909956_Real-time_monophonic_singing_pitch_detection

### Smart-Median Pitch Contour Smoothing

- 來源：Faghih and Timoney, 2022, Applied Sciences.
- 原文開頭摘句："estimated pitch contour usually has errors"; "contour type and the result’s final applications"
- 研究重點：即時 pitch detector 的原始 contour 會有錯誤，需要 smoothing/post-processing 才適合回饋。
- 可應用突破：聲海看到的紅線不應直接等於原始偵測值，否則 octave jump、短暫斷音、vibrato 都可能被誤判。需要先做 smoothing 與 outlier handling，再把結果轉成使用者能理解的偏高/偏低/穩定度。
- 聲海用法：使用者看到的紅色偏差線應該經過平滑與 confidence filter，避免抖動。
- MVP 影響：建立 `PitchContourSmoother`，處理 octave jump、短暫錯偵、vibrato。
- Link: https://www.mdpi.com/2076-3417/12/14/7026

## 3. Audio-to-MIDI / 歌聲轉可編輯音符

### Basic Pitch

- 來源：Spotify Engineering, 2022.
- 原文開頭摘句："including your voice"; "fast and computationally lightweight"
- 研究重點：Basic Pitch 是輕量 audio-to-MIDI 模型，支援 voice、pitch bend、polyphonic/instrument-agnostic 轉 MIDI。
- 可應用突破：聲海可以先用 Basic Pitch 研究「使用者唱完後轉成 MIDI/音符時間線」的可行性。這能把聲音紀錄從單純音檔變成可與譜面比對的資料，未來支援錯音定位、樂句重播與練習回顧。
- 聲海用法：可作為「使用者唱完後轉成 MIDI note timeline」的研究工具，幫助比對譜面旋律。
- MVP 影響：先不要自己訓練 audio-to-MIDI；先用 Basic Pitch/CREPE 作研究 baseline。
- Link: https://engineering.atspotify.com/2022/06/meet-basic-pitch

### Onsets and Frames

- 來源：Google Research, 2018.
- 原文開頭摘句："jointly predict onsets and frames"; "predicts pitch onset events"
- 研究重點：音符辨識不能只看 frame pitch；onset/offset 對音樂感知很重要。
- 可應用突破：聲海如果要做「節奏準不準」或「有沒有晚進/早進」，不能只追音高，還要追 onset。MVP 可以先做音高，下一階段把使用者開始唱的時間點和譜面小節位置對齊。
- 聲海用法：未來做節奏/進拍準確度時，要把 onset 偵測納入，而不是只看音高。
- MVP 影響：Phase 2 先做 pitch；Phase 3 加入 onset timing 與節奏偏差。
- Link: https://research.google/pubs/onsets-and-frames-dual-objective-piano-transcription/

## 4. 資料集與驗證

### VocalSet

- 來源：Wilkins et al., 2018, ISMIR/Zenodo.
- 原文開頭摘句："10.1 hours of 20 professional singers"; "17 different vocal techniques"
- 研究重點：VocalSet 包含不同 vowel、voice type、vocal technique、scales、arpeggios、long tones、excerpts。
- 可應用突破：聲海需要自己的 evaluation，不然只會做出「在我自己的聲音上看起來可以」的 demo。VocalSet 可以用來測不同母音、不同唱法、不同聲部下 pitch tracker 是否穩定，尤其是檢查 octave error 和 vibrato 誤判。
- 聲海用法：用它建立 pitch tracker regression tests，檢查不同母音與唱法下是否發生 octave error。
- MVP 影響：建立 `research/evaluation/`，記錄每個演算法在不同 vocal technique 的錯誤類型。
- Link: https://zenodo.org/record/1492452

## 5. Breath / 身體狀態回饋：MVP 後續

### Sensing the Breath

- 來源：Piao and Xia, 2022, NIME/arXiv.
- 原文開頭摘句："breathing states"; "improve pitch accuracy in vocal training"
- 研究重點：呼吸狀態與 pitch contour 一起視覺化，對某些使用者能幫助音準與呼吸深度。
- 可應用突破：聲海 MVP 不需要立刻做硬體或穿戴裝置，但可以先把「聲音日記」設計成能記錄氣息、疲勞、狀態的資料結構。這讓未來若加入呼吸 sensor 或 Apple Watch 生理資料，不需要重做整個產品架構。
- 聲海用法：MVP 不做 wearable，但聲音日記可先記錄「氣息感、疲勞、今日狀態」。
- MVP 影響：聲音日記欄位可設計為未來 breath sensor 的資料插槽。
- Link: https://arxiv.org/abs/2202.01439

## 6. 產品設計結論

- 聲海的主軸應是「譜面導向的科學化練習」，不是單純 tuner。
- 即時回饋要包含：目標音高、實際音高、偏差 cents、confidence、平滑後趨勢。
- 分析單位要從單音擴展到：音程、短句、小節、聲部段落。
- 演算法架構要可替換：`PitchTracker`、`PitchContourSmoother`、`NoteAligner`、`PracticeScorer`。
- 使用者心理很重要：低信心偵測不應被顯示成錯誤，避免 app 變成挫折製造器。
- MVP 可先做 MusicXML/手動匯入 + pitch feedback；OMR 和 audio-to-MIDI 用研究工具作 baseline。

## 7. 可轉成任務的下一步

- 建立 Swift protocol：`PitchTracker`、`PitchContourSmoother`、`PitchDeviationAnalyzer`。
- 在 `ScoreDocument` 增加 `practiceSessions`、`pitchSamples`、`confidence` 欄位。
- 建立一組合法測試音檔：長音、音階、短句、四部合唱片段。
- 研究 Basic Pitch / CREPE 是否能轉 Core ML 或作 server-side research pipeline。
- 設計 UI：譜面上紅色偏差標記 + 下方 pitch contour + session trend。
