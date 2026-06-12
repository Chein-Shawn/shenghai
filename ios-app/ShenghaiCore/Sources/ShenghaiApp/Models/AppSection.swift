import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"
    case cantonese = "yue"
    case spanish = "es"
    case arabic = "ar"
    case russian = "ru"
    case portuguese = "pt"
    case indonesian = "id"
    case japanese = "ja"
    case korean = "ko"
    case thai = "th"
    case italian = "it"
    case german = "de"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var isRightToLeft: Bool {
        self == .arabic
    }

    var nativeDisplayName: String {
        switch self {
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        case .simplifiedChinese: return "简体中文"
        case .cantonese: return "粵語"
        case .spanish: return "Español"
        case .arabic: return "العربية"
        case .russian: return "Русский"
        case .portuguese: return "Português"
        case .indonesian: return "Bahasa Indonesia"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .thai: return "ไทย"
        case .italian: return "Italiano"
        case .german: return "Deutsch"
        }
    }
}

final class AppSettingsStore: ObservableObject, @unchecked Sendable {
    static let shared = AppSettingsStore()

    @Published var selectedLanguage: AppLanguage {
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Self.languageKey)
        }
    }

    private let defaults: UserDefaults
    private static let languageKey = "shenghai.displayLanguage"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.languageKey),
           let storedLanguage = AppLanguage(rawValue: rawValue) {
            selectedLanguage = storedLanguage
        } else {
            selectedLanguage = .english
        }
    }
}

enum L10n {
    static func tr(_ key: String) -> String {
        let language = AppSettingsStore.shared.selectedLanguage
        return translations[language]?[key] ?? key
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, locale: Locale(identifier: AppSettingsStore.shared.selectedLanguage.localeIdentifier), arguments: arguments)
    }

    private static let translations: [AppLanguage: [String: String]] = [
        .traditionalChinese: [
            "Overview": "總覽",
            "Compose": "打譜",
            "Score": "樂譜",
            "Practice": "練習",
            "Experimental": "實驗功能",
            "Research": "研究",
            "Support": "支援",
            "Usage": "使用統計",
            "Shenghai": "聲海",
            "Load Demo Score": "載入示範譜",
            "Export MIDI": "匯出 MIDI",
            "Settings": "設定",
            "Display Language": "顯示語言",
            "Choose the interface language. The change applies immediately across the app.": "選擇介面語言。變更會立即套用到整個 app。",
            "Ready for MusicXML prototype testing.": "MusicXML 原型測試已準備完成。",
            "Loaded demo score: Twinkle excerpt.": "已載入示範譜：小星星片段。",
            "Imported %@.": "已匯入 %@。",
            "Load or import a MusicXML score first.": "請先載入或匯入 MusicXML 樂譜。",
            "Exported MIDI for %@.": "已匯出 %@ 的 MIDI。",
            "selected part": "選定聲部",
            "Load or import a MusicXML candidate first.": "請先載入或匯入 MusicXML 候選檔。",
            "Created editable MusicXML review candidate.": "已建立可編輯的 MusicXML 審查候選。",
            "Created %d notes from Compose.": "已由打譜建立 %d 個音符。",
            "Exported MusicXML: %@.": "已匯出 MusicXML：%@。",
            "Playback stopped.": "播放已停止。",
            "Playback finished.": "播放完成。",
            "Playing %@.": "正在播放 %@。",
            "No score loaded": "尚未載入樂譜",
            "Imported score": "已匯入樂譜",
            "Alpha 0": "Alpha 0",
            "Scan, correct, and practice from editable MusicXML": "從可編輯 MusicXML 進行掃描、校正與練習",
            "Parts": "聲部",
            "Measures": "小節",
            "Playable Notes": "可播放音符",
            "Timeline": "時間線",
            "%d ticks": "%d ticks",
            "MVP Chain": "MVP 主流程",
            "MusicXML composer": "MusicXML 打譜",
            "MusicXML import": "MusicXML 匯入",
            "PDF/image -> editable MusicXML review": "PDF/圖片 -> 可編輯 MusicXML 審查",
            "Main workflow gate: check scanned notes, lyrics, directions, repeats, and layout before practice.": "主流程關卡：在練習前檢查掃描到的音符、歌詞、指示、反覆與版面。",
            "ScoreDocument wrapper": "ScoreDocument 封裝",
            "MIDI event timeline": "MIDI 事件時間線",
            "MIDI playback/export": "MIDI 播放／匯出",
            "Experimental Singing Support Lab": "實驗型歌唱支援實驗室",
            "Non-medical research prototype with safety guardrails.": "帶有安全邊界的非醫療研究原型。",
            "Experimental Sing-to-Dismiss Alarm": "實驗型歌唱解除鬧鐘",
            "Full-song in-app challenge model exists; OS-level alarm behavior depends on platform APIs.": "完整歌曲的 app 內挑戰模型已存在；系統層鬧鐘行為仍受平台 API 限制。",
            "Experimental Text Rhythm Speech Lab": "實驗型文字節奏語音實驗室",
            "Paragraph rhythm guide and speech-practice scoring model exists.": "段落節奏引導與語音練習評分模型已存在。",
            "External OMR engine execution": "外部 OMR 引擎執行",
            "homr/oemer/Audiveris execution still runs outside the Apple app, then imports MusicXML.": "homr/oemer/Audiveris 目前仍在 Apple app 外部執行，再匯入 MusicXML。",
            "Real microphone pitch tracking": "即時麥克風音高追蹤",
            "Core deviation model exists; live tracker is next.": "核心偏差模型已存在；下一步是即時追蹤器。",
            "Open Score": "開啟樂譜",
            "Create a simple MusicXML score, then load it into practice.": "建立簡單的 MusicXML 樂譜，然後載入練習。",
            "Score Settings": "樂譜設定",
            "Title": "標題",
            "Part name": "聲部名稱",
            "Beats": "拍數",
            "Beat Type": "拍號分母",
            "Note Entry": "音符輸入",
            "Rest": "休止符",
            "Pitch": "音高",
            "Accidental": "升降記號",
            "natural": "還原",
            "Octave %d": "八度 %d",
            "Value": "時值",
            "Add Rest": "加入休止符",
            "Add Note": "加入音符",
            "Score Sequence": "樂譜序列",
            "Events": "事件",
            "Duration": "時長",
            "No notes yet": "尚未加入音符",
            "Use Note Entry to create the first MusicXML draft.": "使用音符輸入建立第一份 MusicXML 草稿。",
            "Undo": "復原",
            "Clear": "清除",
            "Load Score": "載入樂譜",
            "Export MusicXML": "匯出 MusicXML",
            "Share MusicXML": "分享 MusicXML",
            "Removed last composed event.": "已移除最後一個打譜事件。",
            "Cleared composition draft.": "已清除打譜草稿。",
            "Added rest.": "已加入休止符。",
            "Added %@.": "已加入 %@。",
            "Note": "音符",
            "Research Map": "研究地圖",
            "Algorithm decisions feeding the MVP": "支撐 MVP 的演算法決策",
            "Product Algorithms": "產品演算法",
            "Current Blockers": "目前卡點",
            "Support & Settings": "支援與設定",
            "Manual, release notes, tester feedback, and app language": "使用手冊、更新紀錄、測試者回饋與 app 語言",
            "Documentation": "文件",
            "User Manual": "使用手冊",
            "Import scores, practice, annotate, and export.": "匯入樂譜、練習、標註與匯出。",
            "Changelog": "更新日誌",
            "New features, fixes, and known issues.": "新功能、修正與已知問題。",
            "Feedback": "回饋",
            "Type": "類型",
            "Summary": "摘要",
            "GitHub Issue": "GitHub 問題",
            "Mail Draft": "郵件草稿",
            "Feedback sends only what you choose to include. For private repos, GitHub Issues are useful for invited internal testers; Mail Draft is the fallback.": "回饋只會送出你選擇填入的內容。對私人 repo 而言，GitHub Issues 適合受邀內測者；郵件草稿則是備用方式。",
            "Bug": "錯誤",
            "Feature": "功能建議",
            "Usability": "易用性",
            "Daily practice trend and feature time": "每日練習趨勢與各功能使用時間",
            "Total Time": "總時間",
            "Sessions": "天數",
            "Active": "目前活動",
            "None": "無",
            "Feature Time": "功能使用時間",
            "Daily Trend": "每日趨勢",
            "Usage appears after you switch between sections.": "切換各區塊之後才會開始出現使用統計。",
            "Microphone permission is required for live pitch tracking.": "即時音高追蹤需要麥克風權限。",
            "Research-backed, unusual singing features": "有研究依據的特殊歌唱功能",
            "Safety Boundary": "安全邊界",
            "Status": "狀態",
            "Protocol": "流程",
            "Length": "時長",
            "%d min": "%d 分鐘",
            "Intended use": "預期用途",
            "Gentle Call-and-Response": "溫和呼應式練習",
            "Metric: %@": "指標：%@",
            "Tracked Metrics": "追蹤指標",
            "prototype": "原型",
            "concept": "概念",
            "pilotReady": "可試行",
            "clinicianReviewRequired": "需專業審查",
            "Demo song": "示範歌曲",
            "Wake time": "喚醒時間",
            "Coverage": "覆蓋率",
            "Pitch target": "音準目標",
            "How dismissal works": "解除條件",
            "Platform boundary": "平台邊界",
            "Prototype flow": "原型流程",
            "Category": "分類",
            "Language": "語言",
            "Phrases": "片語數",
            "Guide": "引導",
            "On": "開",
            "Off": "關",
            "Sample prompt": "示範文本",
            "Segmentation": "切分方式",
            "v1 uses %@ to split bilingual text into phrase units. English keeps word-level cue timing inside each phrase; Chinese and mixed phrases stay phrase-based.": "v1 使用 %@ 將雙語文本切成片語單位。英文在各片語內保留單字級節奏提示；中文與混合語句維持片語級。",
            "Cue span: %d-%d": "提示範圍：%d-%d",
            "Practice metrics": "練習指標",
            "Clarity": "清晰度",
            "Rate": "速度",
            "Rhythm": "節奏",
            "Completion": "完成度",
            "Phrase match": "片語吻合",
            "Phrases/min": "片語/分鐘",
            "English-only sessions can also report words/min: %@.": "純英文模式也會顯示每分鐘單字數：%@。",
            "Boundary": "限制邊界",
            "Evidence Notes": "研究註記",
            "The evidence is mixed and condition-specific. Shenghai uses this section for cautious prototypes, not medical claims.": "目前證據混合，且高度依賴特定情境。聲海將此區塊定位為謹慎的實驗原型，而非醫療宣稱。",
            "App use: %@": "在 app 中的用途：%@",
            "In tune": "音準正確",
            "Sharp": "偏高",
            "Flat": "偏低",
            "Low confidence": "信心不足",
            "Missing target": "缺少目標音",
            "%.1f cents, confidence %.2f": "%.1f 音分，信心 %.2f",
            "confidence %.2f": "信心 %.2f",
            "Pen": "畫筆",
            "Highlighter": "螢光筆",
            "Eraser": "橡皮擦"
        ],
        .simplifiedChinese: [
            "Overview": "总览",
            "Compose": "打谱",
            "Score": "乐谱",
            "Practice": "练习",
            "Experimental": "实验功能",
            "Research": "研究",
            "Support": "支持",
            "Usage": "使用统计",
            "Shenghai": "声海",
            "Load Demo Score": "载入示范谱",
            "Export MIDI": "导出 MIDI",
            "Settings": "设置",
            "Display Language": "显示语言",
            "Choose the interface language. The change applies immediately across the app.": "选择界面语言。更改会立即应用到整个 app。",
            "Ready for MusicXML prototype testing.": "MusicXML 原型测试已准备完成。",
            "Loaded demo score: Twinkle excerpt.": "已载入示范谱：小星星片段。",
            "Imported %@.": "已导入 %@。",
            "Load or import a MusicXML score first.": "请先载入或导入 MusicXML 乐谱。",
            "Exported MIDI for %@.": "已导出 %@ 的 MIDI。",
            "selected part": "选定声部",
            "Load or import a MusicXML candidate first.": "请先载入或导入 MusicXML 候选文件。",
            "Created editable MusicXML review candidate.": "已建立可编辑的 MusicXML 审查候选。",
            "Created %d notes from Compose.": "已由打谱建立 %d 个音符。",
            "Exported MusicXML: %@.": "已导出 MusicXML：%@。",
            "Playback stopped.": "播放已停止。",
            "Playback finished.": "播放完成。",
            "Playing %@.": "正在播放 %@。",
            "No score loaded": "尚未载入乐谱",
            "Imported score": "已导入乐谱",
            "Alpha 0": "Alpha 0",
            "Scan, correct, and practice from editable MusicXML": "从可编辑 MusicXML 进行扫描、校正与练习",
            "Parts": "声部",
            "Measures": "小节",
            "Playable Notes": "可播放音符",
            "Timeline": "时间线",
            "%d ticks": "%d ticks",
            "MVP Chain": "MVP 主流程",
            "Open Score": "打开乐谱",
            "Support & Settings": "支持与设置",
            "Manual, release notes, tester feedback, and app language": "使用手册、更新记录、测试者反馈与 app 语言",
            "Documentation": "文档",
            "User Manual": "使用手册",
            "Changelog": "更新日志",
            "Feedback": "反馈",
            "Type": "类型",
            "Summary": "摘要",
            "GitHub Issue": "GitHub 问题",
            "Mail Draft": "邮件草稿",
            "Bug": "错误",
            "Feature": "功能建议",
            "Usability": "易用性",
            "Total Time": "总时间",
            "Sessions": "天数",
            "Active": "当前活动",
            "None": "无",
            "Feature Time": "功能使用时间",
            "Daily Trend": "每日趋势",
            "Microphone permission is required for live pitch tracking.": "实时音高追踪需要麦克风权限。",
            "Research-backed, unusual singing features": "有研究依据的特殊歌唱功能",
            "Safety Boundary": "安全边界",
            "Status": "状态",
            "Protocol": "流程",
            "Length": "时长",
            "%d min": "%d 分钟",
            "Intended use": "预期用途",
            "Gentle Call-and-Response": "温和呼应式练习",
            "Metric: %@": "指标：%@",
            "Tracked Metrics": "追踪指标",
            "prototype": "原型",
            "concept": "概念",
            "pilotReady": "可试行",
            "clinicianReviewRequired": "需专业审查",
            "Demo song": "示范歌曲",
            "Wake time": "唤醒时间",
            "Coverage": "覆盖率",
            "Pitch target": "音准目标",
            "How dismissal works": "解除条件",
            "Platform boundary": "平台边界",
            "Prototype flow": "原型流程",
            "Category": "分类",
            "Language": "语言",
            "Phrases": "短语数",
            "Guide": "引导",
            "On": "开",
            "Off": "关",
            "Sample prompt": "示范文本",
            "Segmentation": "切分方式",
            "v1 uses %@ to split bilingual text into phrase units. English keeps word-level cue timing inside each phrase; Chinese and mixed phrases stay phrase-based.": "v1 使用 %@ 将双语文本切成短语单位。英文在各短语内保留单词级节奏提示；中文与混合语句维持短语级。",
            "Cue span: %d-%d": "提示范围：%d-%d",
            "Practice metrics": "练习指标",
            "Clarity": "清晰度",
            "Rate": "速度",
            "Rhythm": "节奏",
            "Completion": "完成度",
            "Phrase match": "短语吻合",
            "Phrases/min": "短语/分钟",
            "English-only sessions can also report words/min: %@.": "纯英文模式也会显示每分钟单词数：%@。",
            "Boundary": "限制边界",
            "Evidence Notes": "研究注记",
            "The evidence is mixed and condition-specific. Shenghai uses this section for cautious prototypes, not medical claims.": "目前证据混合，且高度依赖特定情境。声海将此区块定位为谨慎的实验原型，而非医疗宣称。",
            "App use: %@": "在 app 中的用途：%@",
            "In tune": "音准正确",
            "Sharp": "偏高",
            "Flat": "偏低",
            "Low confidence": "置信不足",
            "Missing target": "缺少目标音",
            "%.1f cents, confidence %.2f": "%.1f 音分，置信 %.2f",
            "confidence %.2f": "置信 %.2f",
            "Pen": "画笔",
            "Highlighter": "荧光笔",
            "Eraser": "橡皮擦"
        ],
        .cantonese: [
            "Overview": "總覽",
            "Compose": "打譜",
            "Score": "樂譜",
            "Practice": "練習",
            "Experimental": "實驗功能",
            "Research": "研究",
            "Support": "支援",
            "Usage": "使用統計",
            "Settings": "設定",
            "Display Language": "顯示語言"
        ],
        .spanish: [
            "Overview": "Resumen",
            "Compose": "Componer",
            "Score": "Partitura",
            "Practice": "Práctica",
            "Experimental": "Experimental",
            "Research": "Investigación",
            "Support": "Soporte",
            "Usage": "Uso",
            "Shenghai": "Shenghai",
            "Load Demo Score": "Cargar partitura de demo",
            "Export MIDI": "Exportar MIDI",
            "Settings": "Ajustes",
            "Display Language": "Idioma de la interfaz",
            "Choose the interface language. The change applies immediately across the app.": "Elige el idioma de la interfaz. El cambio se aplica de inmediato en toda la app.",
            "Support & Settings": "Soporte y ajustes",
            "Documentation": "Documentación",
            "Feedback": "Comentarios",
            "Microphone permission is required for live pitch tracking.": "Se requiere permiso de micrófono para el seguimiento de tono en vivo."
        ],
        .arabic: [
            "Overview": "نظرة عامة",
            "Compose": "تأليف",
            "Score": "المدونة",
            "Practice": "تدريب",
            "Experimental": "تجريبي",
            "Research": "بحث",
            "Support": "الدعم",
            "Usage": "الاستخدام",
            "Settings": "الإعدادات",
            "Display Language": "لغة العرض"
        ],
        .russian: [
            "Overview": "Обзор",
            "Compose": "Набор",
            "Score": "Партитура",
            "Practice": "Практика",
            "Experimental": "Эксперимент",
            "Research": "Исследование",
            "Support": "Поддержка",
            "Usage": "Использование",
            "Settings": "Настройки",
            "Display Language": "Язык интерфейса"
        ],
        .portuguese: [
            "Overview": "Visão geral",
            "Compose": "Compor",
            "Score": "Partitura",
            "Practice": "Prática",
            "Experimental": "Experimental",
            "Research": "Pesquisa",
            "Support": "Suporte",
            "Usage": "Uso",
            "Settings": "Configurações",
            "Display Language": "Idioma da interface"
        ],
        .indonesian: [
            "Overview": "Ringkasan",
            "Compose": "Tulis not",
            "Score": "Partitur",
            "Practice": "Latihan",
            "Experimental": "Eksperimental",
            "Research": "Riset",
            "Support": "Bantuan",
            "Usage": "Penggunaan",
            "Settings": "Pengaturan",
            "Display Language": "Bahasa tampilan"
        ],
        .japanese: [
            "Overview": "概要",
            "Compose": "作譜",
            "Score": "譜面",
            "Practice": "練習",
            "Experimental": "実験機能",
            "Research": "研究",
            "Support": "サポート",
            "Usage": "使用状況",
            "Shenghai": "Shenghai",
            "Load Demo Score": "デモ譜面を読み込む",
            "Export MIDI": "MIDI を書き出す",
            "Settings": "設定",
            "Display Language": "表示言語",
            "Choose the interface language. The change applies immediately across the app.": "表示言語を選択します。変更はすぐにアプリ全体へ反映されます。",
            "Ready for MusicXML prototype testing.": "MusicXML プロトタイプのテスト準備ができました。",
            "Support & Settings": "サポートと設定",
            "Documentation": "ドキュメント",
            "Feedback": "フィードバック",
            "Microphone permission is required for live pitch tracking.": "ライブ音高追跡にはマイク権限が必要です。"
        ],
        .korean: [
            "Overview": "개요",
            "Compose": "작보",
            "Score": "악보",
            "Practice": "연습",
            "Experimental": "실험 기능",
            "Research": "연구",
            "Support": "지원",
            "Usage": "사용 통계",
            "Settings": "설정",
            "Display Language": "표시 언어"
        ],
        .thai: [
            "Overview": "ภาพรวม",
            "Compose": "เขียนโน้ต",
            "Score": "โน้ตเพลง",
            "Practice": "ฝึกซ้อม",
            "Experimental": "ทดลอง",
            "Research": "งานวิจัย",
            "Support": "ช่วยเหลือ",
            "Usage": "การใช้งาน",
            "Settings": "การตั้งค่า",
            "Display Language": "ภาษาที่แสดง"
        ],
        .italian: [
            "Overview": "Panoramica",
            "Compose": "Componi",
            "Score": "Partitura",
            "Practice": "Pratica",
            "Experimental": "Sperimentale",
            "Research": "Ricerca",
            "Support": "Supporto",
            "Usage": "Utilizzo",
            "Settings": "Impostazioni",
            "Display Language": "Lingua dell'interfaccia"
        ],
        .german: [
            "Overview": "Übersicht",
            "Compose": "Notieren",
            "Score": "Partitur",
            "Practice": "Üben",
            "Experimental": "Experimentell",
            "Research": "Forschung",
            "Support": "Support",
            "Usage": "Nutzung",
            "Settings": "Einstellungen",
            "Display Language": "Anzeigesprache"
        ]
    ]
}

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case scoreComposer
    case scoreWorkspace
    case practice
    case experimentalFeatures
    case researchStatus
    case support
    case usageStats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return L10n.tr("Overview")
        case .scoreComposer:
            return L10n.tr("Compose")
        case .scoreWorkspace:
            return L10n.tr("Score")
        case .practice:
            return L10n.tr("Practice")
        case .experimentalFeatures:
            return L10n.tr("Experimental")
        case .researchStatus:
            return L10n.tr("Research")
        case .support:
            return L10n.tr("Support")
        case .usageStats:
            return L10n.tr("Usage")
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .scoreComposer:
            return "square.and.pencil"
        case .scoreWorkspace:
            return "music.note.list"
        case .practice:
            return "waveform.and.mic"
        case .experimentalFeatures:
            return "testtube.2"
        case .researchStatus:
            return "book.pages"
        case .support:
            return "questionmark.bubble"
        case .usageStats:
            return "chart.bar.xaxis"
        }
    }

    var usageFeature: UsageFeature {
        switch self {
        case .dashboard:
            return .dashboard
        case .scoreComposer:
            return .scoreComposer
        case .scoreWorkspace:
            return .scoreWorkspace
        case .practice:
            return .practice
        case .experimentalFeatures:
            return .experimentalFeatures
        case .researchStatus:
            return .researchStatus
        case .support:
            return .support
        case .usageStats:
            return .usageStats
        }
    }
}
