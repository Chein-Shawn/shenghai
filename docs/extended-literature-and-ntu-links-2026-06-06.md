# 延伸文獻與台大研究連結｜聲海計畫

遷移日期：2026-06-06

目的：補強聲海各功能的研究依據，並整理可能與聲海功能有關的台大教授、實驗室與論文方向。

## 一、依聲海功能拆解的延伸文獻

### 1. 譜面 OCR / OMR / MusicXML 匯入

**核心問題**

聲海若要支援 PDF/圖片樂譜匯入，技術上不是 OCR，而是 OMR（Optical Music Recognition）。MVP 應優先採用既有 OMR 工具輸出 MusicXML，再由聲海處理聲部、播放與練習資料。

**文獻與來源**

- Shatri & Fazekas, 2020, Optical Music Recognition: State of the Art and Major Challenges.
  - 原文開頭摘句："Usual OMR output formats include MIDI, MusicXML"
  - 聲海可用突破：支持「不要自創主樂譜格式」，先把 MusicXML 當標準交換格式，讓 OMR、MuseScore、播放、聲部練習串起來。
  - Link: https://www.tenor-conference.org/proceedings/2020/23_Shatri_tenor20.pdf
- DoReMi OMR dataset, 2021.
  - 原文開頭摘句："MIDI, MEI, MusicXML and PNG files"
  - 聲海可用突破：未來若要評估 OMR，可用同時含 PNG 與 MusicXML 的資料集做 benchmark，而不是只看 demo 成功。
  - Link: https://arxiv.org/abs/2107.07786
- Multimodal image and audio music transcription, 2021.
  - 原文開頭摘句："combines the predictions from two neural end-to-end OMR and AMT systems"
  - 聲海可用突破：長期可把譜面 OMR 和音訊 AMT 互相校正，例如譜面辨識錯了但音訊旋律能補強。
  - Link: https://link.springer.com/article/10.1007/s13735-021-00221-6

### 2. MusicXML / ScoreDocument / MIDI 播放

**核心問題**

聲海需要把 MusicXML 轉成內部 ScoreDocument，再轉成 MIDI-like timeline，供播放、練習與音準比對使用。

**文獻與來源**

- W3C MusicXML.
  - 原文開頭摘句："MusicXML is the standard open format"
  - 聲海可用突破：MusicXML 作為主交換格式；ScoreDocument 只保存聲海特有資料，如校正、練習、同步點、聲部設定。
  - Link: https://www.w3.org/2021/06/musicxml40/
- MusicXML repeats tutorial.
  - 原文開頭摘句："barline elements can specify repeats"
  - 聲海可用突破：反覆記號與 ending 對實際播放順序很重要；ScoreDocument 需要保存 expanded measure order。
  - Link: https://www.w3.org/2021/06/musicxml40/tutorial/midi-compatible-part/

### 3. 聲部/伴奏分離與練習音軌

**核心問題**

聲海短期可從譜面合成聲部，長期才考慮從 YouTube/音檔做 source separation。分離音訊非常有用，但運算量與品質風險較高。

**文獻與來源**

- Demucs / Hybrid Spectrogram and Waveform Source Separation.
  - 原文開頭摘句："Hybrid Spectrogram and Waveform Source Separation"
  - 聲海可用突破：可作研究 baseline，但 iPhone 端即時跑不一定實際；MVP 可以先做伺服器/離線研究流程。
  - Link: https://arxiv.org/abs/2111.03600
- Open-Unmix.
  - 原文開頭摘句："decomposing music into its constitutive components"
  - 聲海可用突破：可比較不同 source separation 方法；聲海要記錄每個模型對合唱/鋼琴伴奏的失敗類型。
  - Link: https://joss.theoj.org/papers/10.21105/joss.01667
- Spleeter.
  - 原文開頭摘句："source separation library with pretrained models"
  - 聲海可用突破：適合作為快速 demo 或研究 baseline；正式產品仍要評估授權、品質與運算成本。
  - Link: https://github.com/deezer/spleeter

### 4. 跟譜 / Audio-to-Score Alignment / Score Following

**核心問題**

聲海要知道使用者唱到譜面哪裡，才能標記「哪一小節偏高/偏低」。這需要 score following 或 audio-to-score alignment，而不是只做獨立 tuner。

**文獻與來源**

- Musical Score Following and Audio Alignment, 2022.
  - 原文開頭摘句："Real-time tracking of the position of a musical performance"
  - 聲海可用突破：練習模式需要即時追蹤使用者在譜面上的位置，才能做紅色小節標記、段落循環與常錯段落統計。
  - Link: https://arxiv.org/abs/2205.03247
- Automatic alignment of a musical score to performed music.
  - 原文開頭摘句："alignment of a music score ... to a human performance"
  - 聲海可用突破：可從 DTW/MIDI-to-audio alignment 開始，先做離線對齊，再逐步做即時跟譜。
  - Link: https://www.jstage.jst.go.jp/article/ast/22/3/22_3_189/_article/-char/en

### 5. 音高偵測 / Pitch Tracking / 音準回饋

**核心問題**

聲海的音準回饋不能只算頻率；必須處理 confidence、vibrato、octave error、延遲與 smoothing。

**文獻與來源**

- CREPE.
  - 原文開頭摘句："operates directly on the time-domain waveform"
  - 聲海可用突破：先作 reference pitch tracker；Swift 端維持 `PitchTracker` protocol，未來可替換 YIN/pYIN/CREPE/Core ML。
  - Link: https://arxiv.org/abs/1802.06182
- A Comparative Study of Pitch Extraction Algorithms on Singing Sounds.
  - 原文開頭摘句："adapted to singing voice analysis"
  - 聲海可用突破：歌聲不是一般語音，必須依聲部、音域、性別、唱法調參與評估。
  - Link: https://arxiv.org/abs/1912.12609
- Smart-Median pitch contour smoothing.
  - 原文開頭摘句："estimated pitch contour usually has errors"
  - 聲海可用突破：紅色錯音標記前要先 smoothing，避免偵測抖動傷害使用者信心。
  - Link: https://www.mdpi.com/2076-3417/12/14/7026

### 6. 歌聲轉 MIDI / 使用者錄音轉音符

**核心問題**

聲海若要把使用者唱完的聲音轉成可回顧、可比對的音符資料，可先研究 audio-to-MIDI。

**文獻與來源**

- Basic Pitch.
  - 原文開頭摘句："including your voice"
  - 聲海可用突破：可把使用者錄音轉成 MIDI note timeline，和譜面旋律比對，支援錯音定位與練習回顧。
  - Link: https://engineering.atspotify.com/2022/06/meet-basic-pitch/
- Onsets and Frames.
  - 原文開頭摘句："jointly predict onsets and frames"
  - 聲海可用突破：節奏準確度要看 onset，不只看 pitch；未來可做「早進/晚進」提示。
  - Link: https://arxiv.org/abs/1710.11153

### 7. 練習紀錄 / 視覺回饋 / 使用者學習

**核心問題**

聲海的差異化是「持續練習 + 可視化回饋 + 長期紀錄」，不是一次性評分器。

**文獻與來源**

- Real-Time Visual Feedback in Singing Pedagogy.
  - 原文開頭摘句："the voice is invisible to the eye"
  - 聲海可用突破：把抽象聲音變成可視化圖像，是聲海的產品核心。
  - Link: https://www.mdpi.com/2076-3417/12/21/10781
- Concurrent visual feedback and adult singing accuracy.
  - 原文開頭摘句："objective, concurrent feedback"
  - 聲海可用突破：客觀回饋與持續練習要一起設計；應優先做 session trend、streak、常錯小節。
  - Link: https://journals.sagepub.com/doi/abs/10.1177/0305735619854534
- Visual and auditory feedback for poor-pitch remediation.
  - 原文開頭摘句："singing is a learned skill"
  - 聲海可用突破：支持聲海把唱準視為可訓練能力，並支援短樂句/小節練習。
  - Link: https://journals.sagepub.com/doi/abs/10.1177/03057356211026730

### 8. 聲音日記 / 身體狀態 / Breath Feedback

**核心問題**

聲海的聲音日記可先記錄主觀狀態，未來再接呼吸、疲勞、Apple Watch 或感測器資料。

**文獻與來源**

- Sensing the Breath.
  - 原文開頭摘句："breathing states"; "improve pitch accuracy"
  - 聲海可用突破：MVP 不做 wearable，但資料模型應預留 breath/fatigue/status 欄位。
  - Link: https://arxiv.org/abs/2202.01439

## 二、台大教授/實驗室與聲海功能關聯

### 1. 楊奕軒 Yi-Hsuan Yang｜臺大電機系

**官方研究領域**

- Music information research
- Artificial intelligence
- Machine learning
- Music generation

官方頁面指出其研究包含 music analysis，例如 automatic music transcription、source separation、classification，以及 symbolic MIDI / music audio generation。

Link: https://ee.ntu.edu.tw/profile1.php?id=1090726

**和聲海的關聯**

- 最直接對應聲海的音樂 AI / MIR / AMT / source separation / music generation。
- 可支撐聲海的 MusicXML/MIDI/audio-to-MIDI、聲部合成、伴奏生成、歌聲資料分析。

**相關論文**

- KaraSinger: Score-Free Singing Voice Synthesis with VQ-VAE.
  - 原文開頭摘句："score-free SVS"
  - 聲海可用突破：不納入 MVP，但能作為長期 AI 聲音生成/聲部示範音色的研究背景。
  - Link: https://arxiv.org/abs/2110.04005
- Speech-to-Singing Conversion based on Boundary Equilibrium GAN.
  - 原文開頭摘句："converting a speech signal into a singing one"
  - 聲海可用突破：未來若做 AI 聲音示範或練習參考聲，可以研究 speech-to-singing / style transfer。
  - Link: https://arxiv.org/abs/2005.13835
- Mandarin Singing Voice Synthesis with a Phonology-based Duration Model.
  - 原文開頭摘句："generate human-like voice signals from lyrics and the corresponding musical scores"
  - 聲海可用突破：若未來支援中文/華語歌唱，音節、聲調與 note duration 對自然度很重要。
  - Link: https://scholars.lib.ntu.edu.tw/entities/publication/44589125-110d-48fb-947f-b47c7c068264

### 2. 陳宏銘 Homer H. Chen｜臺大電機系

**官方研究領域**

- Multimedia signal processing
- Computational photography and display
- Music data mining

Link: https://ee.ntu.edu.tw/profile1.php?id=60

**和聲海的關聯**

- 對應聲海的 music data mining、練習資料分析、推薦、情緒/聲音日記、內容檢索。
- 可支撐聲海把「練習資料」做成趨勢、分類、推薦與回顧，而不是只存紀錄。

**相關成果**

- Music Emotion Recognition, Yang & Chen, CRC Press, 2011.
  - 原文開頭摘句：課程頁列為 "music emotion recognition"
  - 聲海可用突破：未來聲音日記與年度回顧可加入情緒/曲目狀態分析。
  - Link: https://web.ee.ntu.edu.tw/course_detail.php?CA_ID=6450
- Toward multi-modal music emotion classification.
  - 原文開頭摘句："multi-modal music emotion classification"
  - 聲海可用突破：可把音訊、文字日記、曲目 metadata 共同用於練習回顧與推薦。
  - Link: https://scholars.lib.ntu.edu.tw/entities/publication/4c3da30b-5e06-41dd-a909-f895cf9429de

### 3. 張智星 Jyh-Shing Roger Jang｜臺大資工/網媒所

**官方研究領域**

- Music Analysis and Retrieval
- Speech Recognition and Synthesis
- Multimedia Information Retrieval

Link: https://www.inm.ntu.edu.tw/en/Departmentmember/Faculty/Jyh-Shing-Roger-Jang-73615798

**和聲海的關聯**

- 對應聲海的 music analysis/retrieval、speech/singing synthesis、評分、歌聲資料處理。
- 和聲海的「從譜面/音訊建立可練習資料」非常接近。

**相關論文**

- Zero-Shot Singing Voice Synthesis from Musical Score.
  - 原文開頭摘句："only musical score as the musical content condition"
  - 聲海可用突破：長期可研究從 score 產生可聽的聲部參考音軌。
  - Link: https://scholars.lib.ntu.edu.tw/entities/publication/714a4716-1020-479c-adfb-eaac4595e8dd
- A corpus-based singing voice synthesis system for Mandarin Chinese.
  - 原文開頭摘句："corpus-based singing voice synthesis"
  - 聲海可用突破：支撐華語歌唱聲音合成、音節與聲音資料庫設計。
  - Link: https://scholars.lib.ntu.edu.tw/entities/publication/64311535-6685-4c42-8320-d9e243119752
- Singer separation for karaoke content generation.
  - 原文開頭摘句："separate singing voice from mono audio music"
  - 聲海可用突破：和 YouTube/音檔分離聲部、伴奏控制、練習音軌高度相關。
  - Link: https://arxiv.org/abs/2110.06707

### 4. 李宏毅 Hung-yi Lee｜臺大電機系

**官方研究領域**

- Spoken Language Understanding
- Speech Recognition
- Machine Learning

Link: https://scholars.lib.ntu.edu.tw/handle/123456789/717540

**和聲海的關聯**

- 對應聲海的聲音表示學習、voice conversion、speech/singing processing、弱標註/自監督學習。
- 對聲海的「少資料也要做出可用聲音模型」特別重要。

**相關論文**

- Zero-Shot Singing Voice Synthesis from Musical Score.
  - 原文開頭摘句："zero-shot singing voice synthesis"
  - 聲海可用突破：長期可探索少量使用者聲音樣本產生個人化參考聲部，但不放入 MVP。
  - Link: https://scholars.lib.ntu.edu.tw/entities/publication/714a4716-1020-479c-adfb-eaac4595e8dd
- SUPERB: Speech processing Universal PERformance Benchmark.
  - 原文開頭摘句："benchmark the performance ... across a wide range of speech processing tasks"
  - 聲海可用突破：聲海也應建立自己的 singing-practice benchmark，避免只憑主觀 demo 判斷演算法好壞。
  - Link: https://ai.meta.com/research/publications/superb-speech-processing-universal-performance-benchmark/
- Toward Degradation-Robust Voice Conversion.
  - 原文開頭摘句："degradation robustness"
  - 聲海可用突破：真實使用者手機錄音會有噪音、殘響與裝置差異，需做 robust voice/pitch analysis。
  - Link: https://arxiv.org/abs/2110.07537

### 5. 蔡振家 Chen-gia Tsai｜臺大音樂學研究所

**官方研究領域**

- Biomusicology
- Music psychology
- Music acoustics
- Affective science
- Cognitive neuroscience of music

Link: https://gim.ntu.edu.tw/%E5%B0%88%E4%BB%BB%E5%B8%AB%E8%B3%87/%E8%94%A1%E6%8C%AF%E5%AE%B6/

**和聲海的關聯**

- 對應聲海的使用者練習心理、音樂認知、聲音/表演藝術中的生理與情感反應。
- 適合支撐聲海「如何讓使用者願意持續練」、「回饋如何不造成挫折」這類非純工程問題。

**可延伸方向**

- 聲海內測時加入音樂心理量表或訪談。
- 設計「可視化回饋是否改善練習動機」的使用者研究。
- 聲音日記可加入主觀疲勞、情緒、身體狀態欄位。

### 6. 陳炳宇 Bing-Yu Chen / 袁千雯 Chien-Wen Yuan｜臺大 HCI / D-School

**官方研究領域**

- 陳炳宇：Human-Computer Interaction, Computer Graphics, Image Processing.
- 袁千雯：Computer-mediated communication, HCI, CSCW, health/wellbeing design.

Links:

- https://tbd.ntu.edu.tw/?p=821
- https://tbd.ntu.edu.tw/?p=1111

**和聲海的關聯**

- 不是聲音演算法核心，但對聲海的產品體驗、練習流程、社群/合唱團協作與內測研究很有用。
- 若要參賽，HCI 研究方法可以幫聲海把「使用者真的會不會用」講清楚。

**可延伸方向**

- 設計合唱團員的練習流程觀察。
- 研究紅色錯誤標記是否造成焦慮，並比較不同 feedback UI。
- 設計老師/學生、團員/指揮之間的資料分享界線。

## 三、對聲海開發的結論

### 近期 MVP 應優先研究

1. MusicXML / ScoreDocument / MIDI timeline：先把譜面資料變成可播放、可練習、可比對。
2. Pitch tracking + smoothing：音準偵測要有 confidence，不要直接用紅色懲罰使用者。
3. Score following / audio alignment：要能把使用者唱的位置對到譜面小節。
4. Practice log：把每次練習的時間、曲目、聲部、偏差、錯誤段落保存。
5. Evaluation：用 VocalSet 或自建合法資料測試不同 pitch tracker 和 smoother。

### 台大最直接可關聯教授

- 楊奕軒：最直接對應 MIR、automatic music transcription、source separation、music generation。
- 張智星：music analysis/retrieval、speech/singing synthesis、karaoke/singer separation。
- 李宏毅：speech/audio representation、voice conversion、singing voice synthesis、benchmark。
- 陳宏銘：music data mining、music emotion recognition、multimedia signal processing。
- 蔡振家：music psychology、music acoustics、affective science，支撐訓練心理與使用者研究。
- 陳炳宇 / 袁千雯：HCI/CSCW，支撐產品互動、內測方法、協作設計。

### 可以轉成任務

- 建立 `research/evaluation/`，收集合法測試音檔與評估指標。
- 實作 `NoteAligner`，先用離線 DTW 對齊 MusicXML/MIDI 與 pitch contour。
- 建立 `PitchTracker` adapter，支援先接 Python CREPE/Basic Pitch，再規劃 Core ML。
- 設計內測問卷：練習動機、回饋理解度、紅色標記壓力、持續使用意願。
- 在 Notion Research & References 資料庫中加入上述教授/論文作為後續閱讀清單。
