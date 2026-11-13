require "import"
import "android.content.Context"
import "android.content.Intent"
import "android.content.ClipData"
import "android.content.ComponentName"
import "java.util.Locale"
import "java.util.Arrays"
import "java.lang.System"
import "java.lang.Long"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.speech.RecognizerIntent"
import "android.media.AudioManager"
import "android.os.Build"
import "android.os.SystemClock"
import "java.lang.Runnable"
import "android.speech.tts.TextToSpeech"
import "android.app.AlertDialog"
import "android.content.DialogInterface"
import "android.view.WindowManager"
import "android.net.Uri"
import "android.media.MediaPlayer"
import "android.widget.LinearLayout"
import "android.widget.TextView"
import "android.widget.SeekBar"
import "android.os.Handler"
import "android.os.Looper"
import "android.os.Bundle"
import "android.text.InputType"
import "android.widget.EditText"
import "android.widget.CheckBox"
import "android.widget.Button"
import "android.view.View"
import "android.widget.ScrollView"
import "android.view.accessibility.AccessibilityNodeInfo"
import "java.io.File"
import "java.io.FileInputStream"
import "java.io.InputStreamReader"
import "java.io.BufferedReader"
import "java.io.FileOutputStream"
import "java.io.OutputStreamWriter"
import "java.io.BufferedWriter"
import "java.net.URL"
import "java.lang.StringBuilder"
import "java.lang.Thread"

local deviceLanguageCode = "en"
do
    local resolved, code = pcall(function()
        return tostring(Locale.getDefault().getLanguage()):lower()
    end)
    if resolved and code ~= "" and code ~= "nil" then
        deviceLanguageCode = code
    end
end

local uiIndonesian = deviceLanguageCode == "in" or deviceLanguageCode == "id"

local function T(indonesian, english)
    if uiIndonesian then
        return indonesian
    end
    return english
end

local extensionName = "Input suara Pro Bjr Offline"

do
    local function normalizeName(text)
        return (tostring(text):lower():gsub("[^%w]", ""))
    end

    local sources = {}
    for level = 1, 20 do
        local found, info = pcall(function()
            return debug.getinfo(level, "S")
        end)
        if not found or info == nil then
            break
        end
        local origin = info.source
        if type(origin) == "string" and origin:sub(1, 1) == "@" then
            sources[#sources + 1] = origin:sub(2)
        end
    end
    for _, variable in ipairs({ "luapath", "luadir" }) do
        local read, value = pcall(function()
            return _G[variable]
        end)
        if read and type(value) == "string" and value:find("\n", 1, true) == nil then
            sources[#sources + 1] = value
        end
    end

    local expected = normalizeName(extensionName)
    local matched = false
    local mismatched = false
    for _, source in ipairs(sources) do
        local segments = {}
        for segment in source:gsub("\\", "/"):gmatch("[^/]+") do
            segments[#segments + 1] = segment
        end
        for index = 1, #segments - 1 do
            if segments[index]:lower() == "plugin" then
                local installed = segments[index + 1]:gsub("%.[Ll][Uu][Aa]$", "")
                if installed:lower() ~= "main" then
                    if normalizeName(installed) == expected then
                        matched = true
                    else
                        mismatched = true
                    end
                end
                break
            end
        end
    end

    if mismatched and not matched then
        local message = T("Nama ekstensi telah diubah. Nama yang benar adalah ", "The extension name has been changed. The correct name is ") .. extensionName .. "."
        pcall(function()
            service.speak(message)
        end)
        error(message, 0)
    end
end

local substitutionTable = {
    ["chino"] = "Jieshuo"
}

local languageTags = { "", "id-ID", "en-US", "en-GB" }
local languageNames = { T("Bawaan perangkat", "Device default"), T("Bahasa Indonesia", "Indonesian"), "English (US)", "English (UK)" }

local logicIndonesian = uiIndonesian
do
    local index = 1
    pcall(function()
        index = this.getSharedPreferences("pengaturan_input_suara", Context.MODE_PRIVATE).getInt("bahasa", 1)
    end)
    if index < 1 or index > #languageTags then
        index = 1
    end
    local tag = languageTags[index]
    local code = deviceLanguageCode
    if tag ~= "" then
        code = tag:sub(1, 2):lower()
    end
    logicIndonesian = code == "id" or code == "in"
end

local function pickLogic(indonesian, english)
    if logicIndonesian then
        return indonesian
    end
    return english
end

local function chooseSet(indonesian, english)
    if logicIndonesian then
        return indonesian
    end
    local result = {}
    for item in english:gmatch("[^,]+") do
        result[item] = true
    end
    return result
end

local triggerPrefix = pickLogic("bahasa", "language")
local orWord = pickLogic("atau", "or")

local languageTriggers = pickLogic({
    { "inggris", "en" },
    { "jawa", "jw" },
    { "sunda", "su" },
    { "palembang", "palembang" },
    { "aceh", "ace" },
    { "bali", "ban" },
    { "minangkabau", "min" },
    { "minang", "min" },
    { "madura", "mad" },
    { "makassar", "mak" },
    { "batak%s+toba", "bbc" },
    { "batak%s+karo", "btx" },
    { "batak%s+simalungun", "bts" },
    { "batak", "bbc" },
    { "spanyol", "es" },
    { "belanda", "nl" },
    { "arab", "ar" },
    { "portugis", "pt" },
    { "prancis", "fr" },
    { "perancis", "fr" },
    { "jerman", "de" },
    { "italia", "it" },
    { "jepang", "ja" },
    { "korea", "ko" },
    { "mandarin", "zh-CN" },
    { "cina", "zh-CN" },
    { "china", "zh-CN" },
    { "tionghoa", "zh-CN" },
    { "rusia", "ru" },
    { "hindi", "hi" },
    { "turki", "tr" },
    { "thailand", "th" },
    { "thai", "th" },
    { "vietnam", "vi" },
    { "melayu", "ms" },
    { "malaysia", "ms" },
    { "filipina", "tl" },
    { "tagalog", "tl" },
    { "urdu", "ur" },
    { "persia", "fa" },
    { "bengali", "bn" },
    { "swahili", "sw" },
    { "yunani", "el" },
    { "polandia", "pl" },
    { "swedia", "sv" },
    { "ukraina", "uk" },
    { "ibrani", "iw" },
    { "khmer", "km" },
    { "kamboja", "km" },
    { "myanmar", "my" },
    { "nepal", "ne" },
    { "tamil", "ta" },
    { "latin", "la" }
}, {
    { "english", "en" },
    { "indonesian", "id" },
    { "spanish", "es" },
    { "french", "fr" },
    { "german", "de" },
    { "italian", "it" },
    { "dutch", "nl" },
    { "portuguese", "pt" },
    { "arabic", "ar" },
    { "javanese", "jw" },
    { "sundanese", "su" },
    { "japanese", "ja" },
    { "korean", "ko" },
    { "chinese", "zh-CN" },
    { "russian", "ru" },
    { "hindi", "hi" },
    { "turkish", "tr" },
    { "mandarin", "zh-CN" },
    { "acehnese", "ace" },
    { "balinese", "ban" },
    { "minangkabau", "min" },
    { "madurese", "mad" },
    { "makassarese", "mak" },
    { "batak%s+toba", "bbc" },
    { "batak%s+karo", "btx" },
    { "batak%s+simalungun", "bts" },
    { "batak", "bbc" },
    { "thai", "th" },
    { "vietnamese", "vi" },
    { "malay", "ms" },
    { "filipino", "tl" },
    { "tagalog", "tl" },
    { "urdu", "ur" },
    { "persian", "fa" },
    { "bengali", "bn" },
    { "swahili", "sw" },
    { "greek", "el" },
    { "polish", "pl" },
    { "swedish", "sv" },
    { "ukrainian", "uk" },
    { "hebrew", "iw" },
    { "khmer", "km" },
    { "burmese", "my" },
    { "nepali", "ne" },
    { "tamil", "ta" },
    { "latin", "la" }
})

local languageTriggerWords = {}
for _, spec in ipairs(languageTriggers) do
    languageTriggerWords[spec[1]] = true
end

local channelLinks = {
    "https://t.me/+k7GNTc2TgOIzMzVl",
    "https://t.me/aksesibelblinkcorporation",
    "https://t.me/+iP6ydsYt4ZthZDU1",
    "https://t.me/+6fnUjM3o2_djZTdl",
    "https://t.me/+m1RHUqx8ucQxZTI1",
    "https://t.me/media_dunia_tunanetra_official",
    "https://t.me/lenariosblind"
}

local pauseNames = { T("Peka", "Sensitive"), T("Sedang", "Medium"), T("Santai", "Relaxed"), T("Pendek", "Short"), T("Panjang", "Long"), T("Tanpa batas", "No limit") }

local vibrationModeNames = { T("Nonaktif", "Off"), T("Sedang", "Medium"), T("Kecil", "Small"), T("Besar", "Large"), T("Awal", "Start"), T("Akhir", "End") }
local vibrationDurations = { 0, 100, 40, 220, 100, 100 }
local vibrationStartModes = { [2] = true, [3] = true, [4] = true, [5] = true }
local vibrationEndModes = { [2] = true, [3] = true, [4] = true, [6] = true }
local pauseLevels = { { 220, 520 }, { 360, 780 }, { 600, 1250 }, { 150, 360 }, { 820, 1650 }, { 220, 520 } }
local pauseMinWords = { 1, 2, 3, 1, 5, 1 }
local pauseResumeLevels = { 60, 80, 110, 45, 140, 60 }
local pauseVoiceRatio = { 0.53, 0.43, 0.33, 0.63, 0.28, 0.53 }
local pauseVoiceFloor = { 2.5, 2.1, 1.7, 2.9, 1.5, 2.5 }
local pauseEndSilence = { 2000, 2600, 3800, 1700, 4600, 15000 }
local pauseMinVoiced = { 140, 220, 360, 100, 520, 140 }
local pauseAnchorSettleMs = 300
local pauseTrailingMs = 120
local pauseAnchorTolerance = 3
local pausePartialLatency = 500
local pausePartialBurst = 3

local errorMessages = {
    [1] = T("Pengenalan suara gagal. Unduh paket bahasa offline di pengaturan suara Google.", "Speech recognition failed. Download the offline language pack in Google voice settings."),
    [2] = T("Pengenalan suara tidak tersedia. Unduh paket bahasa offline di pengaturan suara Google.", "Speech recognition is not available. Download the offline language pack in Google voice settings."),
    [3] = T("Perekaman audio gagal.", "Audio recording failed."),
    [4] = T("Layanan pengenalan suara bermasalah.", "The speech recognition service has a problem."),
    [8] = T("Pengenal suara sedang sibuk. Coba lagi.", "The speech recognizer is busy. Try again."),
    [9] = T("Izin mikrofon belum diberikan.", "Microphone permission has not been granted."),
    [10] = T("Pengenalan suara terlalu sering dipakai. Tunggu sebentar lalu coba lagi.", "Speech recognition is used too often. Wait a moment and try again."),
    [11] = T("Layanan pengenalan suara terputus. Coba lagi.", "The speech recognition service was disconnected. Try again."),
    [12] = T("Bahasa ini belum didukung. Pilih bahasa lain, atau unduh paket bahasa offline di pengaturan suara Google.", "This language is not supported yet. Choose another language, or download the offline language pack in Google voice settings."),
    [13] = T("Paket bahasa belum tersedia. Unduh paket bahasa offline di pengaturan suara Google.", "The language pack is not available. Download the offline language pack in Google voice settings."),
    [14] = T("Pemeriksaan dukungan pengenalan suara gagal. Coba lagi.", "The speech recognition support check failed. Try again."),
    [15] = T("Unduhan paket bahasa offline tidak bisa dipantau. Coba lagi.", "The offline language pack download could not be monitored. Try again.")
}

local questionStarters = chooseSet({
    ["apa"] = true,
    ["apakah"] = true,
    ["siapa"] = true,
    ["siapakah"] = true,
    ["kapan"] = true,
    ["dimana"] = true,
    ["kemana"] = true,
    ["darimana"] = true,
    ["mengapa"] = true,
    ["kenapa"] = true,
    ["bagaimana"] = true,
    ["gimana"] = true,
    ["berapa"] = true,
    ["mana"] = true,
    ["bisakah"] = true,
    ["bolehkah"] = true,
    ["adakah"] = true,
    ["kok"] = true,
    ["memangnya"] = true,
    ["emangnya"] = true,
    ["seberapa"] = true,
    ["ngapain"] = true
}, "what,who,whom,whose,when,where,why,how,which,is,are,was,were,do,does,did,can,could,would,will,should,shall,may,might,have,has,had,isn,aren,wasn,weren,doesn,didn,wouldn,couldn,shouldn,haven,hasn")

local questionLeadWords = chooseSet({
    ["halo"] = true,
    ["hai"] = true,
    ["nah"] = true,
    ["jadi"] = true,
    ["oke"] = true,
    ["iya"] = true,
    ["eh"] = true,
    ["lalu"] = true,
    ["terus"] = true,
    ["tapi"] = true,
    ["tetapi"] = true,
    ["namun"] = true,
    ["kemudian"] = true,
    ["permisi"] = true,
    ["maaf"] = true,
    ["sebenarnya"] = true,
    ["dan"] = true,
    ["atau"] = true,
    ["oh"] = true,
    ["wah"] = true,
    ["lho"] = true,
    ["loh"] = true,
    ["yah"] = true,
    ["hmm"] = true,
    ["ok"] = true,
    ["okay"] = true,
    ["baik"] = true,
    ["baiklah"] = true,
    ["sekarang"] = true,
    ["begini"] = true,
    ["assalamualaikum"] = true,
    ["waalaikumsalam"] = true
}, "hello,hi,hey,so,well,okay,ok,yes,yeah,oh,wow,hmm,and,or,but,then,now,please,excuse,sorry,actually,alright,right,um,uh,listen")

local questionPrepositions = chooseSet({
    ["di"] = true,
    ["ke"] = true,
    ["dari"] = true,
    ["untuk"] = true,
    ["dengan"] = true,
    ["sejak"] = true,
    ["buat"] = true,
    ["sampai"] = true,
    ["pada"] = true,
    ["kepada"] = true,
    ["oleh"] = true,
    ["bagi"] = true,
    ["hingga"] = true,
    ["sama"] = true,
    ["terhadap"] = true,
    ["bareng"] = true,
    ["tanpa"] = true
}, "to,from,with")

local questionTargets = chooseSet({
    ["apa"] = true,
    ["siapa"] = true,
    ["mana"] = true,
    ["kapan"] = true,
    ["berapa"] = true
}, "whom,where")

local connectorWords = chooseSet({
    ["yang"] = true,
    ["di"] = true,
    ["ke"] = true,
    ["dari"] = true,
    ["untuk"] = true,
    ["dengan"] = true,
    ["pada"] = true,
    ["dalam"] = true,
    ["dan"] = true,
    ["atau"] = true,
    ["karena"] = true,
    ["bahwa"] = true,
    ["agar"] = true,
    ["supaya"] = true,
    ["sebagai"] = true,
    ["oleh"] = true
}, "and,or,but,of,to,from,for,with,at,in,on,by,the,a,an,that,which,because,as,than,if,into,about")

local introWords = chooseSet({
    ["halo"] = true,
    ["hai"] = true,
    ["nah"] = true,
    ["jadi"] = true,
    ["namun"] = true,
    ["kemudian"] = true,
    ["selanjutnya"] = true,
    ["akhirnya"] = true,
    ["sebenarnya"] = true,
    ["misalnya"] = true,
    ["artinya"] = true,
    ["pokoknya"] = true,
    ["intinya"] = true,
    ["singkatnya"] = true
}, "hello,hi,hey,well,however,therefore,moreover,furthermore,meanwhile,finally,actually,basically,honestly,anyway,otherwise,instead,firstly,secondly,thirdly")

local starterWords = chooseSet({
    ["nah"] = true,
    ["kemudian"] = true,
    ["selanjutnya"] = true,
    ["intinya"] = true,
    ["pokoknya"] = true,
    ["singkatnya"] = true
}, "anyway,basically,finally,honestly,actually,essentially,alright")

local starterPairs = chooseSet({
    ["setelah itu"] = true,
    ["selain itu"] = true,
    ["dengan demikian"] = true
}, "after that,besides that,in addition,as a result,in conclusion,in short,even so")

local contrastWords = chooseSet({
    ["tetapi"] = true,
    ["tapi"] = true,
    ["namun"] = true,
    ["sedangkan"] = true,
    ["melainkan"] = true,
    ["padahal"] = true
}, "but,however,although,whereas,though,yet")

local runWords = chooseSet({
    ["sehingga"] = true,
    ["supaya"] = true,
    ["agar"] = true,
    ["sambil"] = true,
    ["sedangkan"] = true,
    ["karena"] = true,
    ["jika"] = true,
    ["kalau"] = true,
    ["ketika"] = true,
    ["apabila"] = true,
    ["dan"] = true,
    ["atau"] = true,
    ["untuk"] = true,
    ["dengan"] = true
}, "so,because,since,while,although,unless,whereas,and,or,but,which,until,once,whenever")

local starterMinimum = { 3, 4, 6, 2, 8, 3 }
local runMinimum = { 7, 10, 14, 5, 17, 7 }
local andMinimum = { 7, 10, 14, 5, 6, 7 }

local exclamationStarters = chooseSet({
    ["awas"] = true,
    ["wow"] = true,
    ["hore"] = true,
    ["astaga"] = true,
    ["ayo"] = true,
    ["aduh"] = true,
    ["wah"] = true,
    ["betapa"] = true,
    ["alangkah"] = true,
    ["hati-hati"] = true,
    ["yuk"] = true
}, "watch,wow,hooray,yay,oops,ouch,congratulations,careful,whoa,beware")

local autoExclamationStarters = chooseSet({
    ["mari"] = true,
    ["subhanallah"] = true,
    ["astaghfirullah"] = true,
    ["astagfirullah"] = true,
    ["masyaallah"] = true
}, "congratulations,hallelujah,bravo")

local autoShortExclamationStarters = chooseSet({
    ["jangan"] = true,
    ["silakan"] = true,
    ["silahkan"] = true,
    ["tunggu"] = true,
    ["diam"] = true,
    ["sabar"] = true,
    ["cepat"] = true,
    ["bangun"] = true,
    ["mantap"] = true,
    ["gawat"] = true
}, "don,stop,hurry,beware")

local frontedClauseWords = chooseSet({
    ["kalau"] = true,
    ["jika"] = true,
    ["apabila"] = true,
    ["bila"] = true,
    ["ketika"] = true,
    ["saat"] = true,
    ["setelah"] = true,
    ["sesudah"] = true,
    ["sebelum"] = true,
    ["meskipun"] = true,
    ["walaupun"] = true,
    ["andai"] = true,
    ["seandainya"] = true,
    ["selama"] = true,
    ["karena"] = true
}, "if,when,while,after,before,although,though,since,because,once,unless,whenever,until,whereas,wherever")

local autoStarterWords = chooseSet({
    ["alhamdulillah"] = true,
    ["subhanallah"] = true,
    ["astaghfirullah"] = true,
    ["assalamualaikum"] = true,
    ["waalaikumsalam"] = true,
    ["baiklah"] = true,
    ["permisi"] = true
}, "alright,hello,hi,hey,hallelujah")

local autoStarterPairs = chooseSet({
    ["sementara itu"] = true,
    ["sebelum itu"] = true,
    ["sesudah itu"] = true,
    ["meskipun demikian"] = true,
    ["walaupun demikian"] = true,
    ["meskipun begitu"] = true,
    ["walaupun begitu"] = true,
    ["pada akhirnya"] = true,
    ["pada dasarnya"] = true,
    ["pada intinya"] = true,
    ["selamat pagi"] = true,
    ["selamat siang"] = true,
    ["selamat sore"] = true,
    ["selamat petang"] = true,
    ["selamat malam"] = true
}, "after that,before that,even so,in fact,good morning,good afternoon,good evening,good night,thank you,excuse me,of course")

local autoStarterTriples = chooseSet({
    ["oleh karena itu"] = true,
    ["oleh sebab itu"] = true,
    ["dengan kata lain"] = true,
    ["di sisi lain"] = true
}, "as a result,in other words,on the other hand,in the end")

local autoIntroWords = chooseSet({
    ["alhamdulillah"] = true,
    ["subhanallah"] = true,
    ["astaghfirullah"] = true,
    ["assalamualaikum"] = true,
    ["waalaikumsalam"] = true,
    ["baiklah"] = true,
    ["permisi"] = true,
    ["iya"] = true,
    ["ya"] = true,
    ["oke"] = true,
    ["maaf"] = true,
    ["sebelumnya"] = true,
    ["sebaliknya"] = true,
    ["alhasil"] = true,
    ["oh"] = true
}, "alright,hello,hi,hey,okay,yes,yeah,sorry,however,otherwise,anyway,meanwhile,finally,therefore,instead,oh,well,hallelujah")

local autoIntroPairs = chooseSet({
    ["mohon maaf"] = true,
    ["tentu saja"] = true,
    ["sebagai contoh"] = true,
    ["oh iya"] = true
}, "of course,for instance,oh yes,oh well,in fact,for example")

local autoCommaWords = chooseSet({
    ["sehingga"] = true,
    ["yaitu"] = true,
    ["yakni"] = true,
    ["misalnya"] = true,
    ["contohnya"] = true,
    ["terutama"] = true,
    ["maka"] = true,
    ["berarti"] = true,
    ["niscaya"] = true
}, "namely,especially,therefore,thus,hence,meaning")

local autoConclusionWords = chooseSet({
    ["maka"] = true,
    ["berarti"] = true,
    ["niscaya"] = true
}, "then,therefore,thus,hence")

local berartiVerbPrevious = chooseSet({
    ["itu"] = true,
    ["ini"] = true,
    ["tersebut"] = true,
    ["hal"] = true,
    ["yang"] = true,
    ["tidak"] = true,
    ["tak"] = true,
    ["bukan"] = true,
    ["belum"] = true,
    ["jangan"] = true,
    ["sangat"] = true,
    ["amat"] = true,
    ["sungguh"] = true,
    ["paling"] = true,
    ["cukup"] = true,
    ["terlalu"] = true,
    ["kurang"] = true,
    ["lebih"] = true,
    ["sama"] = true,
    ["juga"] = true,
    ["pun"] = true,
    ["pasti"] = true,
    ["mungkin"] = true,
    ["bisa"] = true,
    ["akan"] = true,
    ["sudah"] = true,
    ["telah"] = true,
    ["sedang"] = true,
    ["masih"] = true,
    ["selalu"] = true,
    ["sering"] = true,
    ["bakal"] = true
}, "")

local berartiVerbFollowing = chooseSet({
    ["bagi"] = true,
    ["buat"] = true,
    ["sekali"] = true,
    ["banget"] = true,
    ["banyak"] = true,
    ["sedikit"] = true,
    ["lebih"] = true,
    ["apa"] = true
}, "")

local autoQuestionWords = chooseSet({
    ["siapa"] = true,
    ["kapan"] = true,
    ["mengapa"] = true,
    ["kenapa"] = true,
    ["bagaimana"] = true,
    ["gimana"] = true,
    ["berapa"] = true
}, "who,when,why,how,where")

local questionWords = chooseSet({
    ["apa"] = true,
    ["siapa"] = true,
    ["kapan"] = true,
    ["mana"] = true,
    ["mengapa"] = true,
    ["kenapa"] = true,
    ["berapa"] = true,
    ["bagaimana"] = true,
    ["gimana"] = true,
    ["dimana"] = true,
    ["kemana"] = true,
    ["darimana"] = true
}, "what,who,when,where,why,how,whom")

local questionBlockers = chooseSet({
    ["tahu"] = true,
    ["tau"] = true,
    ["paham"] = true,
    ["mengerti"] = true,
    ["ingat"] = true,
    ["lupa"] = true,
    ["bertanya"] = true,
    ["menanyakan"] = true,
    ["tanyakan"] = true,
    ["tanya"] = true,
    ["ceritakan"] = true,
    ["menceritakan"] = true,
    ["jelaskan"] = true,
    ["menjelaskan"] = true,
    ["katakan"] = true,
    ["beritahu"] = true,
    ["kira"] = true,
    ["tebak"] = true,
    ["entah"] = true,
    ["lihat"] = true,
    ["dengar"] = true,
    ["cari"] = true,
    ["mencari"] = true,
    ["bilang"] = true,
    ["kabari"] = true,
    ["peduli"] = true,
    ["terserah"] = true,
    ["tergantung"] = true,
    ["bingung"] = true,
    ["ragu"] = true,
    ["penasaran"] = true,
    ["heran"] = true,
    ["menebak"] = true,
    ["mengira"] = true,
    ["mengetahui"] = true,
    ["periksa"] = true,
    ["memeriksa"] = true,
    ["cek"] = true,
    ["tunjukkan"] = true,
    ["pikirkan"] = true,
    ["memikirkan"] = true,
    ["menyadari"] = true,
    ["sadar"] = true,
    ["pastikan"] = true,
    ["memastikan"] = true,
    ["dengarkan"] = true,
    ["simak"] = true
}, "know,knew,wonder,wondered,understand,remember,forget,forgot,ask,asked,tell,told,explain,explained,say,said,guess,see,saw,hear,heard,find,found,check,show,showed,care,depends,depend,confused,unsure,curious,realize,realized,sure,decide,decided,imagine,notice,noticed,learn,learned,idea,clue")

local questionLinkers = chooseSet({
    ["tentang"] = true,
    ["soal"] = true,
    ["mengenai"] = true,
    ["seperti"] = true,
    ["sampai"] = true,
    ["hingga"] = true,
    ["sejak"] = true,
    ["kalau"] = true,
    ["jika"] = true,
    ["bila"] = true,
    ["apabila"] = true,
    ["terserah"] = true
}, "about,regarding,like,until,since,if,whether,depending")

local pronounWords = chooseSet({
    ["saya"] = true,
    ["aku"] = true,
    ["dia"] = true,
    ["ia"] = true,
    ["kami"] = true,
    ["kita"] = true,
    ["mereka"] = true,
    ["kamu"] = true,
    ["anda"] = true,
    ["kalian"] = true
}, "i,he,she,we,they")

local longSplitWords = chooseSet({
    ["lalu"] = true,
    ["terus"] = true,
    ["makanya"] = true,
    ["soalnya"] = true
}, "then,so,because")

local longMinimum = { 7, 10, 14, 5, 17, 7 }

local questionMinimum = { 2, 2, 3, 2, 4, 2 }

local secondPersonWords = chooseSet({
    ["kamu"] = true,
    ["kau"] = true,
    ["engkau"] = true,
    ["dikau"] = true,
    ["anda"] = true,
    ["kalian"] = true
}, "you")

local subjectAuxWords = chooseSet({
    ["sedang"] = true,
    ["lagi"] = true,
    ["sudah"] = true,
    ["udah"] = true,
    ["belum"] = true,
    ["mau"] = true,
    ["akan"] = true,
    ["bakal"] = true,
    ["bisa"] = true,
    ["boleh"] = true,
    ["pernah"] = true,
    ["masih"] = true,
    ["tadi"] = true,
    ["tidak"] = true,
    ["nggak"] = true,
    ["enggak"] = true,
    ["gak"] = true,
    ["suka"] = true,
    ["punya"] = true,
    ["ada"] = true,
    ["harus"] = true,
    ["perlu"] = true,
    ["ingin"] = true,
    ["pengen"] = true,
    ["mulai"] = true,
    ["sempat"] = true,
    ["jadi"] = true
}, "am,is,are,was,were,will,would,can,could,should,must,might,do,does,did,have,has,had,just,not,never,always,still,also,already,really,often,usually,want,need,like,love,got,going")

local clauseJoiners = chooseSet({
    ["ketika"] = true,
    ["saat"] = true,
    ["setelah"] = true,
    ["sesudah"] = true,
    ["sebelum"] = true,
    ["meskipun"] = true,
    ["walaupun"] = true,
    ["biar"] = true,
    ["andai"] = true,
    ["seandainya"] = true,
    ["selagi"] = true,
    ["selama"] = true,
    ["sementara"] = true,
    ["asalkan"] = true,
    ["begitu"] = true,
    ["kecuali"] = true,
    ["seolah"] = true,
    ["seakan"] = true,
    ["serta"] = true
}, "when,while,after,before,although,though,since,because,until,unless,whenever,once,if,whereas,that,whether,as")

local timeGreetings = chooseSet({
    ["pagi"] = true,
    ["siang"] = true,
    ["sore"] = true,
    ["petang"] = true,
    ["malam"] = true
}, "morning,afternoon,evening,night")

local kahExceptions = chooseSet({
    ["langkah"] = true,
    ["melangkah"] = true,
    ["berkah"] = true,
    ["mekah"] = true,
    ["makkah"] = true,
    ["barakah"] = true,
    ["barokah"] = true,
    ["bertengkah"] = true
}, "")

local alternativeEndings = chooseSet({
    ["tidak"] = true,
    ["bukan"] = true,
    ["belum"] = true,
    ["nggak"] = true,
    ["enggak"] = true,
    ["gak"] = true,
    ["ngga"] = true,
    ["ga"] = true
}, "not,no")

local perfectWords = chooseSet({
    ["sudah"] = true,
    ["udah"] = true,
    ["telah"] = true,
    ["pernah"] = true,
    ["sempat"] = true
}, "already,ever")

local questionStarterPairs = chooseSet({
    ["bisa tolong"] = true,
    ["boleh tolong"] = true,
    ["boleh minta"] = true,
    ["boleh saya"] = true,
    ["bisa saya"] = true,
    ["bisa kamu"] = true,
    ["boleh kita"] = true,
    ["masa iya"] = true,
    ["masa sih"] = true,
    ["ada apa"] = true,
    ["ada siapa"] = true,
    ["ada berapa"] = true
}, "how come,so what")

local continuationWords = chooseSet({
    ["dan"] = true,
    ["atau"] = true,
    ["yang"] = true,
    ["karena"] = true,
    ["agar"] = true,
    ["supaya"] = true,
    ["sehingga"] = true,
    ["bahwa"] = true,
    ["dengan"] = true,
    ["untuk"] = true,
    ["sambil"] = true
}, "and,or,that,because,so,with,for,to,of,the,a,an,but,which,while,since")

local trailingAdverbs = chooseSet({
    ["sekarang"] = true,
    ["tadi"] = true,
    ["nanti"] = true,
    ["besok"] = true,
    ["kemarin"] = true,
    ["lagi"] = true,
    ["sih"] = true,
    ["dong"] = true,
    ["deh"] = true,
    ["tuh"] = true,
    ["nih"] = true
}, "now,today,later,tomorrow,yesterday,again,though,tonight")

local timeUnits = chooseSet({
    ["hari"] = true,
    ["malam"] = true,
    ["pagi"] = true,
    ["siang"] = true,
    ["sore"] = true,
    ["minggu"] = true,
    ["bulan"] = true,
    ["tahun"] = true
}, "day,night,morning,afternoon,evening,week,month,year")

local statementSubjects = chooseSet({
    ["saya"] = true,
    ["aku"] = true,
    ["dia"] = true,
    ["ia"] = true,
    ["kami"] = true,
    ["kita"] = true,
    ["mereka"] = true,
    ["beliau"] = true
}, "i,he,she,we,they")

local statementPredicates = chooseSet({
    ["baik"] = true,
    ["sehat"] = true,
    ["senang"] = true,
    ["lapar"] = true,
    ["haus"] = true,
    ["capek"] = true,
    ["lelah"] = true,
    ["sibuk"] = true,
    ["sedih"] = true,
    ["bahagia"] = true,
    ["setuju"] = true,
    ["pergi"] = true,
    ["pulang"] = true,
    ["datang"] = true,
    ["makan"] = true,
    ["minum"] = true,
    ["tahu"] = true,
    ["lihat"] = true,
    ["dengar"] = true,
    ["rasa"] = true,
    ["pikir"] = true,
    ["butuh"] = true,
    ["cari"] = true
}, "fine,good,happy,hungry,thirsty,tired,busy,sad,ready,going,coming,leaving,eating,drinking,thinking,agree,know,see,hear,feel,think,need,want,looking")

local negationModifiers = chooseSet({
    ["juga"] = true,
    ["pun"] = true,
    ["masih"] = true,
    ["sudah"] = true,
    ["udah"] = true,
    ["memang"] = true,
    ["selalu"] = true,
    ["pasti"] = true
}, "also,still,already,really,always,certainly,definitely")

local selfSubjects = chooseSet({
    ["saya"] = true,
    ["aku"] = true,
    ["gue"] = true,
    ["gua"] = true,
    ["kami"] = true
}, "i,we")

local unknowingNegations = chooseSet({
    ["tidak"] = true,
    ["kurang"] = true,
    ["belum"] = true,
    ["nggak"] = true,
    ["enggak"] = true,
    ["gak"] = true,
    ["ga"] = true
}, "don,didn,not,never,can,cannot,won")

local abbreviationWords = chooseSet({
    ["dr"] = true,
    ["drs"] = true,
    ["prof"] = true,
    ["ir"] = true,
    ["no"] = true,
    ["jl"] = true,
    ["hj"] = true,
    ["bpk"] = true,
    ["sdr"] = true,
    ["pt"] = true,
    ["cv"] = true,
    ["tn"] = true,
    ["ny"] = true,
    ["dll"] = true,
    ["dsb"] = true,
    ["dst"] = true,
    ["yth"] = true,
    ["tlp"] = true
}, "dr,mr,mrs,ms,prof,sr,jr,st,no,vs,etc,inc,ltd,co,corp,dept")

local function literalPattern(word)
    return (word:gsub(".", function(char)
        if char:match("%a") then
            return "[" .. char:lower() .. char:upper() .. "]"
        end
        if char:match("%p") then
            return "%" .. char
        end
        return char
    end))
end

local substitutionRules = {}
for word, substitution in pairs(substitutionTable) do
    if word ~= "" then
        substitutionRules[#substitutionRules + 1] = {
            key = word,
            pattern = "%f[%w]" .. literalPattern(word) .. "%f[%W]",
            replacement = (substitution:gsub("%%", "%%%%"))
        }
    end
end
table.sort(substitutionRules, function(a, b)
    return #a.key > #b.key
end)

local addressTopLevels = " com co id net org edu gov info biz io xyz online store site app dev ai tv me sg my us uk "

local function isAddressToken(token)
    if token:find("://", 1, true) ~= nil or token:find("@", 1, true) ~= nil or token:lower():find("^www%.") ~= nil then
        return true
    end
    local lowered = token:lower()
    local label = lowered:match("^[%w%-%.]+%.(%a+)/") or lowered:match("^[%w%-%.]+%.(%a+)[,;:%.!%?]*$")
    return label ~= nil and addressTopLevels:find(" " .. label .. " ", 1, true) ~= nil
end

local function capitalizeFirstWord(text)
    local result = text:gsub("^([%s\"%(]*)()(%a)", function(prefix, position, letter)
        if isAddressToken(text:match("^%S+", position)) then
            return prefix .. letter
        end
        return prefix .. letter:upper()
    end)
    return result
end

local function substituteWords(text)
    for _, rule in ipairs(substitutionRules) do
        text = text:gsub(rule.pattern, rule.replacement)
    end
    return text
end

local function capitalizeAfterPeriod(text)
    local result = text:gsub("()([%.%?!\n])([%s\"%(]*)(%a)", function(position, mark, gap, letter)
        local token = text:match("^%S+", position + #mark + #gap)
        if token ~= nil and isAddressToken(token) then
            return mark .. gap .. letter
        end
        if mark == "\n" then
            return mark .. gap .. letter:upper()
        end
        if gap == "" then
            return mark .. letter
        end
        if gap:find("\n", 1, true) == nil and gap:match('^"+%s*$') ~= nil then
            return mark .. gap .. letter
        end
        if mark == "." and position > 1 and text:sub(position - 1, position - 1) == "." then
            return mark .. gap .. letter
        end
        return mark .. gap .. letter:upper()
    end)
    return result
end

local function splitWords(text)
    local words = {}
    for word in text:gmatch("%S+") do
        words[#words + 1] = word
    end
    return words
end

local function endsWithPunctuation(word)
    return word:match("[%.,!%?;:]$") ~= nil
end

local function plainWord(word)
    local core = (word or ""):lower():match("^[\"'%(%[]*(%a[%a%-]*)")
    if core == nil then
        return ""
    end
    return (core:gsub("%-+$", ""))
end

local function isKahWord(word)
    return logicIndonesian and #word > 4 and word:sub(-3) == "kah" and not kahExceptions[word]
end

local function isQuestionStart(words, index, to)
    local first = plainWord(words[index])
    local second = ""
    local third = ""
    if index < to then
        second = plainWord(words[index + 1])
    end
    if index + 1 < to then
        third = plainWord(words[index + 2])
    end
    if questionStarters[first] then
        if second == "pun" then
            return false
        end
        if second == "saja" then
            return third == "yang" or third == ""
        end
        return true
    end
    if secondPersonWords[first] and autoQuestionWords[second] then
        return third ~= "pun" and third ~= "saja"
    end
    if isKahWord(first) then
        return true
    end
    if questionPrepositions[first] and questionTargets[second] then
        return third ~= "pun"
    end
    return questionStarterPairs[first .. " " .. second] == true
end

local function allowsTrailing(text)
    return text ~= "" and text:match("[%(%-_/\n]$") == nil and not endsWithPunctuation(text)
end

local function addressedBefore(words, from, index)
    for k = math.max(from, index - 2), index - 1 do
        if secondPersonWords[plainWord(words[k])] then
            return true
        end
    end
    return false
end

local function questionBlocked(words, from, to)
    for j = from, to - 1 do
        if questionBlockers[plainWord(words[j])] and not addressedBefore(words, from, j) then
            return true
        end
    end
    return false
end

local function addressedQuestion(words, from, to)
    for j = from, to - 1 do
        if questionBlockers[plainWord(words[j])] and addressedBefore(words, from, j) then
            for k = j + 1, to do
                if questionWords[plainWord(words[k])] then
                    return true
                end
            end
        end
    end
    return false
end

local function questionTail(words, from, to)
    local tail = to
    local steps = 0
    while tail - from >= 2 and steps < 2 do
        local word = plainWord(words[tail])
        if trailingAdverbs[word] then
            tail = tail - 1
        elseif word == "ini" and tail - from >= 3 and timeUnits[plainWord(words[tail - 1])] then
            tail = tail - 2
        else
            break
        end
        steps = steps + 1
    end
    return tail
end

local function addressedChoice(words, from, to)
    local j = from
    while j < to and questionLeadWords[plainWord(words[j])] do
        j = j + 1
    end
    if j + 3 > to or not secondPersonWords[plainWord(words[j])] or not subjectAuxWords[plainWord(words[j + 1])] then
        return false
    end
    for k = j + 2, to - 1 do
        if plainWord(words[k]) == orWord then
            return true
        end
    end
    return false
end

local function endsWithQuestion(words, from, to)
    if to - from < 1 then
        return false
    end
    local tail = questionTail(words, from, to)
    local last = plainWord(words[tail])
    local before = plainWord(words[tail - 1])
    local ending = questionWords[last] == true or last == "kan" or isKahWord(last)
    if not ending and before == orWord and alternativeEndings[last] then
        ending = true
    end
    if not ending and last == "bukan" and tail - from >= 2 then
        ending = true
    end
    if not ending and last == "belum" and tail - from >= 2 then
        for j = from, tail - 1 do
            if perfectWords[plainWord(words[j])] then
                ending = true
            end
        end
    end
    if not ending and alternativeEndings[last] and tail - from >= 2 and not negationModifiers[before] then
        for j = from, tail - 2 do
            if secondPersonWords[plainWord(words[j])] then
                ending = true
                break
            end
        end
    end
    if not ending and addressedChoice(words, from, tail) then
        ending = true
    end
    if ending then
        return not questionBlocked(words, from, tail)
    end
    return addressedQuestion(words, from, to)
end

local function questionHead(words, from, to)
    local index = from
    local skipped = 0
    while index < to and skipped < 3 do
        local word = plainWord(words[index])
        if questionLeadWords[word] then
            index = index + 1
        elseif word == "selamat" and timeGreetings[plainWord(words[index + 1])] then
            index = index + 2
        elseif word == triggerPrefix and languageTriggerWords[plainWord(words[index + 1])] then
            index = index + 2
        else
            break
        end
        skipped = skipped + 1
    end
    if index > to then
        index = to
    end
    return index
end

local function isExclamation(words, from, to, auto)
    local first = plainWord(words[from])
    local count = to - from + 1
    if first == "selamat" then
        if timeGreetings[plainWord(words[from + 1])] then
            return count <= 3
        end
        return count <= 8
    end
    if first == "tolong" then
        return count <= 4
    end
    if exclamationStarters[first] then
        return true
    end
    if auto and autoShortExclamationStarters[first] == true and count <= 6 then
        return true
    end
    return auto and autoExclamationStarters[first] == true
end

local function lastClauseStart(words, boundaries, from, to)
    for j = to - 1, from, -1 do
        if boundaries[j] == "," or words[j]:sub(-1) == "," then
            return j + 1
        end
    end
    return from
end

local function endsWithQuestionClause(words, boundaries, from, to)
    local clause = lastClauseStart(words, boundaries, from, to)
    if clause == from or to - clause < 2 then
        return false
    end
    local first = plainWord(words[clause])
    if not isKahWord(first) and not autoQuestionWords[first] then
        return false
    end
    if plainWord(words[clause + 1]) == "pun" then
        return false
    end
    return not questionBlocked(words, from, to + 1)
end

local function reportedQuestion(words, from, to)
    local head = questionHead(words, from, to)
    for p = head + 2, to - 1 do
        if selfSubjects[plainWord(words[p])] then
            local blocked = false
            for k = head + 1, p - 1 do
                if questionBlockers[plainWord(words[k])] then
                    blocked = true
                    break
                end
            end
            if not blocked then
                for n = p + 1, math.min(p + 3, to - 1) do
                    if unknowingNegations[plainWord(words[n])] then
                        for b = n + 1, math.min(n + 2, to) do
                            if questionBlockers[plainWord(words[b])] then
                                return true
                            end
                        end
                        break
                    end
                end
            end
        end
    end
    return false
end

local function sentenceMark(words, from, to, auto, boundaries)
    if isQuestionStart(words, questionHead(words, from, to), to) and not reportedQuestion(words, from, to) then
        return "?"
    end
    if endsWithQuestion(words, from, to) then
        return "?"
    end
    if boundaries ~= nil and endsWithQuestionClause(words, boundaries, from, to) then
        return "?"
    end
    if isExclamation(words, from, to, auto) then
        return "!"
    end
    return "."
end

local function wordWeight(word)
    local syllables = 0
    for _ in word:lower():gmatch("[aeiou]+") do
        syllables = syllables + 1
    end
    for _ in word:gmatch("%d") do
        syllables = syllables + 1
    end
    if syllables < 1 then
        syllables = 1
    end
    return syllables + 0.3
end

local function nearestBoundary(cumulative, target, totalWords)
    local best = 1
    local bestDistance = math.abs(cumulative[1] - target)
    for i = 2, totalWords - 1 do
        local distance = math.abs(cumulative[i] - target)
        if distance < bestDistance then
            best = i
            bestDistance = distance
        end
    end
    return best
end

local function avoidConnector(words, index)
    local steps = 0
    while index > 1 and steps < 2 do
        local word = plainWord(words[index])
        if not connectorWords[word] and not isKahWord(word) then
            break
        end
        index = index - 1
        steps = steps + 1
    end
    return index
end

local function placePauses(words, pauses, voicedTotal, minWords)
    local totalWords = #words
    local boundaries = {}
    local cumulative = {}
    local sum = 0
    for i = 1, totalWords do
        sum = sum + wordWeight(words[i])
        cumulative[i] = sum
    end
    local entries = {}
    for _, pause in ipairs(pauses) do
        local index = pause.index
        if index == nil and totalWords > 1 and voicedTotal > 0 and voicedTotal - pause.voiced >= pauseTrailingMs then
            index = nearestBoundary(cumulative, sum * pause.voiced / voicedTotal, totalWords)
            local anchor = pause.anchor
            if anchor ~= nil and anchor >= 1 and anchor < totalWords and math.abs(anchor - index) <= pauseAnchorTolerance then
                index = anchor
            end
        end
        if index ~= nil and index >= 1 and index < totalWords then
            entries[#entries + 1] = { index = avoidConnector(words, index), mark = pause.mark }
        end
    end
    table.sort(entries, function(a, b)
        if a.index ~= b.index then
            return a.index < b.index
        end
        return a.mark == "." and b.mark ~= "."
    end)
    local last = 0
    local marked = {}
    for _, entry in ipairs(entries) do
        if entry.mark == "." or entry.index - last >= minWords then
            if boundaries[entry.index] ~= "." then
                boundaries[entry.index] = entry.mark
                marked[entry.index] = entry.mark
            end
            last = entry.index
        end
    end
    return boundaries, marked
end

local function joinsClause(word)
    return connectorWords[word] == true or questionLinkers[word] == true or questionBlockers[word] == true or contrastWords[word] == true or runWords[word] == true or clauseJoiners[word] == true
end

local function pauseSentenceMark(words, from, to, auto)
    if joinsClause(plainWord(words[to + 1])) then
        return nil
    end
    local count = to - from + 1
    if endsWithQuestion(words, from, to) then
        return "?"
    end
    if count >= 3 and isQuestionStart(words, questionHead(words, from, to), to) and not reportedQuestion(words, from, to) then
        return "?"
    end
    if count >= 3 and isExclamation(words, from, to, auto) then
        return "!"
    end
    return nil
end

local function markSentences(words, boundaries, auto, pauseMarks)
    local start = 1
    for i = 1, #words - 1 do
        if words[i]:match("[%.%?!]$") ~= nil then
            start = i + 1
        elseif boundaries[i] == "." then
            local mark = sentenceMark(words, start, i, auto, boundaries)
            if mark == "." and pauseMarks[i] == "." and continuationWords[plainWord(words[i + 1])] then
                mark = ","
            end
            boundaries[i] = mark
            if mark ~= "," then
                start = i + 1
            end
        elseif boundaries[i] == "," and pauseMarks[i] == "," then
            local mark = pauseSentenceMark(words, start, i, auto)
            if mark ~= nil then
                boundaries[i] = mark
                start = i + 1
            end
        end
    end
    return start
end

local function clauseEnd(boundaries, index, total)
    for j = index, total - 1 do
        if boundaries[j] == "." then
            return j
        end
    end
    return total
end

local function questionSplitLength(words, boundaries, index, total, auto)
    if index <= 2 or index >= total then
        return 0
    end
    local word = plainWord(words[index])
    local isQuestionWord = autoQuestionWords[word] == true or (auto and isKahWord(word))
    local isAddressed = auto and secondPersonWords[word] == true and subjectAuxWords[plainWord(words[index + 1])] == true
    if not isQuestionWord and not isAddressed then
        return 0
    end
    if joinsClause(plainWord(words[index - 1])) then
        return 0
    end
    for back = 2, 3 do
        if index - back >= 1 and questionBlockers[plainWord(words[index - back])] then
            return 0
        end
    end
    if isAddressed then
        local last = clauseEnd(boundaries, index, total)
        if last - index < 2 or not endsWithQuestion(words, index, last) then
            return 0
        end
    end
    return 1
end

local function autoStarterLength(words, i, total)
    local word = plainWord(words[i])
    local second = ""
    local third = ""
    if i < total then
        second = plainWord(words[i + 1])
    end
    if i + 1 < total then
        third = plainWord(words[i + 2])
    end
    if autoStarterTriples[word .. " " .. second .. " " .. third] then
        return 3
    end
    if autoStarterPairs[word .. " " .. second] then
        return 2
    end
    if autoStarterWords[word] then
        return 1
    end
    return 0
end

local function startsStatementAfterQuestion(words, index, total, segmentStart, minimum)
    if index >= total or index - segmentStart < minimum then
        return false
    end
    local word = plainWord(words[index])
    local previous = plainWord(words[index - 1])
    local isRequest = word == "tolong"
    if isRequest then
        local closesQuestion = previous == "belum" and endsWithQuestion(words, segmentStart, index - 1)
        if pronounWords[previous] or statementSubjects[previous] or previous == "mohon" or previous == "harap" then
            return false
        end
        if subjectAuxWords[previous] and not closesQuestion then
            return false
        end
    else
        if not statementSubjects[word] then
            return false
        end
        local following = plainWord(words[index + 1])
        if not subjectAuxWords[following] and not statementPredicates[following] then
            return false
        end
    end
    if joinsClause(previous) or questionPrepositions[previous] or questionStarters[previous] or questionWords[previous] then
        return false
    end
    if trailingAdverbs[previous] and index - segmentStart < 3 then
        return false
    end
    if questionBlocked(words, segmentStart, index) then
        return false
    end
    return isQuestionStart(words, questionHead(words, segmentStart, index - 1), index - 1) or endsWithQuestion(words, segmentStart, index - 1)
end

local function conclusionCommaAllowed(words, index)
    local word = plainWord(words[index])
    local previous = plainWord(words[index - 1])
    if joinsClause(previous) then
        return false
    end
    if word ~= "berarti" then
        return true
    end
    if pronounWords[previous] or statementSubjects[previous] or berartiVerbPrevious[previous] then
        return false
    end
    return not berartiVerbFollowing[plainWord(words[index + 1])]
end

local function addFrontedClauseComma(words, boundaries, start, total)
    if not frontedClauseWords[plainWord(words[start])] then
        return nil
    end
    local following = plainWord(words[start + 1])
    if following == "itu" or following == "ini" or following == "demikian" or following == "begitu" then
        return nil
    end
    local last = math.min(start + 9, total - 1)
    for p = start + 1, last do
        if boundaries[p - 1] ~= nil or endsWithPunctuation(words[p - 1]) then
            return nil
        end
        local word = plainWord(words[p])
        local previous = plainWord(words[p - 1])
        if p - start >= 2 and autoConclusionWords[word] and conclusionCommaAllowed(words, p) then
            boundaries[p - 1] = ","
            return p - 1
        end
        if p - start >= 3 and (pronounWords[word] or statementSubjects[word]) and not joinsClause(previous) and not questionPrepositions[previous] then
            boundaries[p - 1] = ","
            return p - 1
        end
    end
    return nil
end

local function addLinguisticMarks(words, boundaries, sensitivity, auto)
    local total = #words
    local starterMin = starterMinimum[sensitivity]
    local questionMin = questionMinimum[sensitivity]
    local statementMin = math.max(2, questionMin - 1)
    local runMin = runMinimum[sensitivity]
    local andMin = andMinimum[sensitivity]
    local segmentStart = 1
    local runStart = 1
    local frontedAt = 0

    for i = 1, total do
        local word = plainWord(words[i])
        local following = ""
        if i < total then
            following = plainWord(words[i + 1])
        end

        if i > 1 then
            local previousMark = boundaries[i - 1]
            local previousWord = words[i - 1]
            if previousMark ~= nil or endsWithPunctuation(previousWord) then
                runStart = i
            end
            if previousMark == "." or previousWord:match("[%.%?!]$") ~= nil then
                segmentStart = i
            end
        end

        local starterLength = 0
        if starterPairs[word .. " " .. following] then
            starterLength = 2
        elseif starterWords[word] then
            starterLength = 1
        end

        if auto and starterLength == 0 then
            starterLength = autoStarterLength(words, i, total)
        end

        local questionSplit = false
        if starterLength == 0 then
            starterLength = questionSplitLength(words, boundaries, i, total, auto)
            questionSplit = starterLength > 0
        end

        if starterLength > 0 and i > segmentStart and i - segmentStart >= (questionSplit and questionMin or starterMin) and boundaries[i - 1] ~= "." and i - 1 ~= frontedAt and not endsWithPunctuation(words[i - 1]) and (questionSplit or not connectorWords[plainWord(words[i - 1])]) and (not questionSplit or auto or boundaries[i - 1] == nil) then
            boundaries[i - 1] = "."
            segmentStart = i
            runStart = i
        end

        if starterLength == 0 and i > segmentStart and boundaries[i - 1] == nil and not endsWithPunctuation(words[i - 1]) and startsStatementAfterQuestion(words, i, total, segmentStart, statementMin) then
            boundaries[i - 1] = "."
            segmentStart = i
            runStart = i
        end

        if auto and i > segmentStart and i < total and boundaries[i - 1] ~= "." and not endsWithPunctuation(words[i - 1]) then
            local previousWord = plainWord(words[i - 1])
            if longSplitWords[word] and words[i]:find("-", 1, true) == nil and i - segmentStart >= longMinimum[sensitivity] and total - i >= 3 and not connectorWords[previousWord] and not pronounWords[previousWord] then
                boundaries[i - 1] = "."
                segmentStart = i
                runStart = i
            end
        end

        if i == segmentStart then
            local phraseLength = starterLength
            if phraseLength == 0 and auto and autoIntroPairs[word .. " " .. following] then
                phraseLength = 2
            end
            if phraseLength >= 2 then
                local last = i + phraseLength - 1
                if last < total and boundaries[last] == nil and not endsWithPunctuation(words[last]) then
                    boundaries[last] = ","
                end
            elseif (introWords[word] or (auto and autoIntroWords[word])) and i < total and boundaries[i] == nil and not endsWithPunctuation(words[i]) then
                boundaries[i] = ","
            end
            if auto and phraseLength < 2 and i < total then
                frontedAt = addFrontedClauseComma(words, boundaries, i, total) or frontedAt
            end
        end

        if auto and (word == "kan" or word == "bukan") and i - segmentStart >= 3 and boundaries[i - 1] == nil and not endsWithPunctuation(words[i - 1]) and (i == total or boundaries[i] == ".") and endsWithQuestion(words, segmentStart, i) then
            boundaries[i - 1] = ","
        end

        if i > segmentStart and i < total and boundaries[i - 1] == nil and not endsWithPunctuation(words[i - 1]) then
            if contrastWords[word] and i - runStart >= 3 then
                boundaries[i - 1] = ","
                runStart = i
            elseif auto and autoCommaWords[word] and i - runStart >= (autoConclusionWords[word] and 2 or 3) and (not autoConclusionWords[word] or conclusionCommaAllowed(words, i)) then
                boundaries[i - 1] = ","
                runStart = i
            elseif runWords[word] and i - runStart >= (word == "dan" and andMin or runMin) and total - i >= 3 then
                boundaries[i - 1] = ","
                runStart = i
            end
        end
    end
end

local function correctRecognizerMarks(words)
    local start = 1
    for i = 1, #words do
        local word = words[i]
        if word:match("[%.%?!]$") ~= nil then
            if i > start and (word == "." or word:match("[^%.]%.$") ~= nil) and not abbreviationWords[plainWord(word)] then
                local last = i
                if word == "." then
                    last = i - 1
                end
                local mark = sentenceMark(words, start, last, true, {})
                if mark ~= "." then
                    words[i] = word:sub(1, -2) .. mark
                end
            end
            start = i + 1
        end
    end
end

local function buildText(text, boundaries)
    local words = splitWords(text)
    local total = #words
    local out = ""
    for i = 1, total do
        local word = words[i]
        if i > 1 then
            out = out .. " "
        end
        out = out .. word
        if i < total and boundaries[i] ~= nil and not endsWithPunctuation(word) then
            out = out .. boundaries[i]
        end
    end
    return out
end

local function refinePunctuation(text)
    local protected = {}
    local result = text:gsub("%S+", function(token)
        local body, tail = token:match("^(.-)([,;%?!%.]*)$")
        if body ~= "" and (body:find("://", 1, true) or body:find("@", 1, true) or body:find("/", 1, true) or body:lower():find("^www%.")) then
            protected[#protected + 1] = body
            return "\1" .. #protected .. "\2" .. tail
        end
        return token
    end)
    result = result:gsub("([^%s])[ \t]+([,;%?!])", "%1%2")
    result = result:gsub("([^%s])[ \t]+%.(%s)", "%1.%2")
    result = result:gsub("([^%s])[ \t]+%.$", "%1.")
    result = result:gsub(",,+", ",")
    result = result:gsub(";;+", ";")
    result = result:gsub("%?%?+", "?")
    result = result:gsub("!!+", "!")
    result = result:gsub("([^%.])%.%.%f[^%.]", "%1.")
    result = result:gsub(",[ \t]*;", ";")
    result = result:gsub(";[ \t]*,", ";")
    result = result:gsub("[,;][ \t]*([%?!])", "%1")
    result = result:gsub("[,;][ \t]*%.%f[^%.]", ".")
    result = result:gsub("([%?!])[ \t]*,", "%1")
    result = result:gsub("([^%.])%.([%?!])", "%1%2")
    result = result:gsub("([%?!])%.%f[^%.]", "%1")
    result = result:gsub("([%w%)])([,;%?!])(%a)", "%1%2 %3")
    result = result:gsub("%([ \t]+", "(")
    result = result:gsub("[ \t]+%)", ")")
    result = result:gsub("\1(%d+)\2", function(index)
        return protected[tonumber(index)]
    end)
    return result
end

local function getPrefs()
    return this.getSharedPreferences("pengaturan_input_suara", Context.MODE_PRIVATE)
end

local profileLayer = { values = nil }

local proLock = {
    check = nil,
    keys = {
        asisten_aktif = true,
        kapital_otomatis = true,
        baris_baru = true,
        tanda_baca_otomatis = true,
        spasi_setelah_teks = true,
        gaya_singkatan = true,
        gaya_jaksel = true,
        gaya_gagap = true,
        gaya_cadel = true,
        ejaan_rapi = true,
        bersihkan_isian = true,
        profil_otomatis = true,
        kamus_aktif = true,
        makro_aktif = true,
        terjemah_output = true
    }
}

local function getFlag(key, fallback)
    if fallback == nil then
        fallback = true
    end
    if proLock.keys[key] == true then
        local checker = proLock.check
        if checker == nil or not checker() then
            return false
        end
    end
    local layered = profileLayer.values
    if layered ~= nil and layered[key] ~= nil then
        return layered[key]
    end
    return getPrefs().getBoolean(key, fallback)
end

local function toggleFlag(key, fallback)
    local value = not getFlag(key, fallback)
    getPrefs().edit().putBoolean(key, value).apply()
    return value
end

local function getLanguageIndex()
    local index = getPrefs().getInt("bahasa", 1)
    if index < 1 or index > #languageTags then
        index = 1
    end
    return index
end

local function getLanguageTag()
    local tag = languageTags[getLanguageIndex()]
    if tag == "" then
        local resolved, deviceTag = pcall(function()
            return tostring(Locale.getDefault().toLanguageTag())
        end)
        if resolved and deviceTag ~= "" then
            return deviceTag
        end
        local locale = Locale.getDefault()
        local language = tostring(locale.getLanguage())
        local country = tostring(locale.getCountry())
        if country == "" then
            return language
        end
        return language .. "-" .. country
    end
    return tag
end

local function getPauseIndex()
    local index = getPrefs().getInt("sensitivitas", 2)
    if index < 1 or index > #pauseLevels then
        index = 2
    end
    return index
end

local function getVibrationMode()
    local index = getPrefs().getInt("getaran_mode", 1)
    if index < 1 or index > #vibrationModeNames then
        index = 1
    end
    return math.floor(index)
end

local function getVibrationStrength()
    local value = getPrefs().getInt("getaran_kekuatan", 100)
    if value < 1 then
        value = 1
    elseif value > 100 then
        value = 100
    end
    return math.floor(value)
end

local function vibrateOnce(duration)
    pcall(function()
        local vibrator = this.getSystemService(Context.VIBRATOR_SERVICE)
        if vibrator == nil then
            return
        end
        local amplitude = math.floor(getVibrationStrength() * 255 / 100 + 0.5)
        if amplitude < 1 then
            amplitude = 1
        end
        local done = pcall(function()
            local VibrationEffect = luajava.bindClass("android.os.VibrationEffect")
            local AudioAttributes = luajava.bindClass("android.media.AudioAttributes")
            local effect = VibrationEffect.createOneShot(duration, amplitude)
            local attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY).build()
            vibrator.vibrate(effect, attributes)
        end)
        if not done then
            done = pcall(function()
                local VibrationEffect = luajava.bindClass("android.os.VibrationEffect")
                vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude))
            end)
        end
        if not done then
            vibrator.vibrate(duration)
        end
    end)
end

local function signalVibration(moment)
    local mode = getVibrationMode()
    local active = false
    if moment == "start" then
        active = vibrationStartModes[mode] == true
    else
        active = vibrationEndModes[mode] == true
    end
    if active then
        vibrateOnce(vibrationDurations[mode])
    end
end

local function playVib()
    local mode = getVibrationMode()
    if mode >= 2 and mode <= 4 then
        vibrateOnce(vibrationDurations[mode])
    end
end

local function feedbackUI()
    playVib()
end

local function stateText(flag)
    if flag then
        return T("Aktif", "On")
    end
    return T("Nonaktif", "Off")
end

local settingsExit = { count = 0, token = 0, player = nil }

local function presentDialog(builder, onDismissed)
    local dialog = nil
    local shown = pcall(function()
        dialog = builder.create()
        pcall(function()
            dialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
        end)
        dialog.show()
    end)
    if not shown then
        shown = pcall(function()
            dialog = builder.create()
            dialog.show()
        end)
    end
    if not shown then
        service.speak(T("Input suara Offline gagal ditampilkan.", "The offline voice input failed to display."))
    end
    if shown and dialog ~= nil then
        settingsExit.count = settingsExit.count + 1
        settingsExit.token = settingsExit.token + 1
        settingsExit.release()
        local closed = false
        pcall(function()
            dialog.setOnDismissListener(DialogInterface.OnDismissListener{
                onDismiss = function(closedDialog)
                    if closed then
                        return
                    end
                    closed = true
                    if onDismissed ~= nil then
                        pcall(onDismissed, closedDialog)
                    end
                    settingsExit.count = math.max(0, settingsExit.count - 1)
                    settingsExit.token = settingsExit.token + 1
                    settingsExit.schedule(settingsExit.token)
                end
            })
        end)
    end
    return dialog
end

local showMainSettings
local showBjrSettings
local showAboutSettings
local showKhususSettings

local function showChoiceSettings(title, names, key, current, announce)
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setSingleChoiceItems(names, current - 1, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            getPrefs().edit().putInt(key, which + 1).apply()
            dialog.dismiss()
            if announce ~= nil then
                announce(which + 1)
            end
            showMainSettings()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            showMainSettings()
        end
    })
    presentDialog(builder)
end

local function showLanguageSettings()
    showChoiceSettings(T("Bahasa pengenalan suara", "Speech recognition language"), languageNames, "bahasa", getLanguageIndex())
end

local function showSensitivitySettings()
    showChoiceSettings(T("Sensitivitas jeda napas", "Breath pause sensitivity"), pauseNames, "sensitivitas", getPauseIndex(), function(index)
        local message = T("Sensitivitas jeda napas: ", "Breath pause sensitivity: ") .. pauseNames[index] .. "."
        if not getFlag("jeda_napas") then
            message = message .. T(" Jeda napas jadi tanda baca masih nonaktif.", " Breath pause as punctuation is still off.")
        end
        service.speak(message)
    end)
end

local function showVibrationStrengthSettings()
    local layout = LinearLayout(this)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(48, 32, 48, 16)

    local label = TextView(this)
    label.setText(T("Kekuatan getaran: ", "Vibration strength: ") .. getVibrationStrength() .. T(" persen", " percent"))
    label.setTextSize(16)

    local slider = SeekBar(this)
    slider.setMax(100)
    slider.setProgress(getVibrationStrength())
    slider.setContentDescription(T("Kekuatan getaran", "Vibration strength"))
    slider.setOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener{
        onProgressChanged = function(seekBar, progress, fromUser)
            if progress < 1 then
                seekBar.setProgress(1)
                return
            end
            label.setText(T("Kekuatan getaran: ", "Vibration strength: ") .. progress .. T(" persen", " percent"))
            if fromUser then
                getPrefs().edit().putInt("getaran_kekuatan", progress).apply()
                vibrateOnce(vibrationDurations[2])
            end
        end,
        onStartTrackingTouch = function(seekBar)
        end,
        onStopTrackingTouch = function(seekBar)
            local progress = seekBar.getProgress()
            if progress < 1 then
                progress = 1
            end
            getPrefs().edit().putInt("getaran_kekuatan", progress).apply()
        end
    })

    layout.addView(label)
    layout.addView(slider)

    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Kekuatan getaran", "Vibration strength"))
    builder.setView(layout)
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            showMainSettings()
        end
    })
    presentDialog(builder)
end

local function openLink(url)
    local opened = pcall(function()
        local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        this.startActivity(intent)
    end)
    if not opened then
        service.speak(T("Tautan channel gagal dibuka.", "The channel link could not be opened."))
    end
end

local guideSections = { loaded = false, load = nil }

local function guideParts(separator)
    if not guideSections.loaded and guideSections.load ~= nil then
        pcall(guideSections.load)
    end
    local parts = {}
    if #guideSections == 0 then
        parts[1] = T("Petunjuk", "Guide") .. separator .. T("File tabel_petunjuk.lua tidak ditemukan atau rusak. Letakkan file tersebut di folder yang sama dengan main.lua.", "The file tabel_petunjuk.lua was not found or is damaged. Put it in the same folder as main.lua.")
        return parts
    end
    for i, section in ipairs(guideSections) do
        parts[i] = section[1] .. separator .. section[2]
    end
    return parts
end

local guideAudio = { engine = nil, token = 0, serial = 0, handler = Handler(Looper.getMainLooper()) }

local function stopGuideAudio()
    guideAudio.token = guideAudio.token + 1
    local engine = guideAudio.engine
    guideAudio.engine = nil
    if engine ~= nil then
        pcall(function()
            engine.stop()
        end)
        pcall(function()
            engine.shutdown()
        end)
    end
end

local function startGuideAudio()
    stopGuideAudio()
    local token = guideAudio.token
    local engine = nil
    local created = pcall(function()
        engine = TextToSpeech(this, TextToSpeech.OnInitListener{
            onInit = function(status)
                if token ~= guideAudio.token or engine == nil then
                    return
                end
                if status ~= TextToSpeech.SUCCESS then
                    stopGuideAudio()
                    service.speak(T("Mesin suara TTS gagal disiapkan.", "The TTS voice engine could not be prepared."))
                    return
                end
                pcall(function()
                    local result = engine.setLanguage(uiIndonesian and Locale("id", "ID") or Locale.getDefault())
                    if result < 0 then
                        engine.setLanguage(Locale.getDefault())
                    end
                end)
                guideAudio.handler.postDelayed(function()
                    if token ~= guideAudio.token then
                        return
                    end
                    for i, part in ipairs(guideParts(". ")) do
                        local spoken = pcall(function()
                            engine.speak(part, TextToSpeech.QUEUE_ADD, nil, "petunjuk" .. i)
                        end)
                        if not spoken then
                            pcall(function()
                                engine.speak(part, TextToSpeech.QUEUE_ADD, nil)
                            end)
                        end
                    end
                end, 1200)
            end
        })
    end)
    if not created or engine == nil then
        service.speak(T("Mesin suara TTS gagal disiapkan.", "The TTS voice engine could not be prepared."))
        return
    end
    guideAudio.engine = engine
end

local function showGuideText(returnToMain)
    local builder = AlertDialog.Builder(this)
    local title = T("Petunjuk penggunaan (teks)", "User guide (text)")
    if returnToMain then
        title = T("Selamat menggunakan alat ini! Yang dibangun oleh mbah dadang asli orang banjarnegara.", "Enjoy using this tool! Built by Mbah Dadang, a native of Banjarnegara.") .. " " .. title
    end
    builder.setTitle(title)
    builder.setMessage(table.concat(guideParts(":\n"), "\n\n"))
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if returnToMain then
                showMainSettings()
            else
                showAboutSettings()
            end
        end
    })
    return presentDialog(builder)
end

local function showGuideAudio()
    guideAudio.serial = guideAudio.serial + 1
    local serial = guideAudio.serial
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Petunjuk penggunaan (audio)", "User guide (audio)"))
    builder.setMessage(T("Petunjuk penggunaan akan dibacakan oleh mesin suara TTS. Tekan Ulangi untuk membaca dari awal, atau Hentikan dan kembali untuk berhenti.", "The user guide will be read aloud by the TTS voice engine. Press Repeat to read from the beginning, or Stop and go back to stop."))
    builder.setPositiveButton(T("Ulangi", "Repeat"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            showGuideAudio()
        end
    })
    builder.setNegativeButton(T("Hentikan dan kembali", "Stop and go back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            stopGuideAudio()
            dialog.dismiss()
            showAboutSettings()
        end
    })
    local dialog = presentDialog(builder, function(closedDialog)
        if guideAudio.serial == serial then
            stopGuideAudio()
        end
    end)
    if dialog ~= nil then
        startGuideAudio()
    end
end

showAboutSettings = function()
    local items = {
        T("Developer file ini: bocah asli Banjarnegara", "Developer of this file: a native boy from Banjarnegara"),
        T("Silakan join grup dan channel telegram di bawah ini untuk mengikuti pembaharuan aplikasi dan ekstensi ataupun pembahasan aplikasi dan ekstensi", "Please join the Telegram groups and channels below to follow updates to the app and extension or to join discussions about them"),
        T("Ruang obrolan Bjr. 👨‍💻 Grup", "Bjr chat room. 👨‍💻 Group"),
        "Aksesibel Blind Corporation channel",
        "Comentary ScreenReader Indonesia🇮🇩 channel",
        "Smart Teknologi channel",
        "Dunia Akses Tunanetra channel",
        "Media Dunia Tunanetra Official channel",
        "Len Arios channel",
        T("Petunjuk penggunaan (teks)", "User guide (text)"),
        T("Petunjuk penggunaan (audio)", "User guide (audio)"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Tentang dan petunjuk penggunaan Bjr", "About and user guide for Bjr"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which < 2 then
                showAboutSettings()
            elseif which - 1 <= #channelLinks then
                openLink(channelLinks[which - 1])
            elseif which == #channelLinks + 2 then
                showGuideText()
            elseif which == #channelLinks + 3 then
                showGuideAudio()
            else
                showMainSettings()
            end
        end
    })
    presentDialog(builder)
end

local khusus = {}

khusus.handler = Handler(Looper.getMainLooper())
khusus.quietRetries = 0
khusus.quietMaxRetries = 3
khusus.triggerQuietRetries = 0
khusus.whisperRatio = 0.38
khusus.whisperFloor = 0.3
khusus.whisperVoiced = 0.6
khusus.noiseSpikeMs = 80
khusus.noiseEndExtraMs = 1500
khusus.launchDelayMs = 0

function khusus.offlineOnly()
    return getFlag("offline_penuh", false) == true
end

function khusus.offlineMessage()
    return T("Mode offline penuh aktif. Fitur ini butuh internet.", "Full offline mode is on. This feature needs internet.")
end
khusus.fallbackErrors = { [1] = true, [2] = true, [12] = true, [13] = true }
khusus.serviceQueue = nil
khusus.serviceIndex = 0
khusus.activeService = nil
khusus.minCompleteSilenceMs = 1200
khusus.maxMacro = 1000
khusus.legacyDir = "/storage/emulated/0/Plugin/input Lokal Pro/"
khusus.userAgent = "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36"
khusus.clients = { "dict-chrome-ex", "at" }
khusus.lastDetected = nil
khusus.macros = nil
khusus.words = nil
khusus.generation = 0
khusus.lastInserted = nil
khusus.undoState = nil
khusus.entryFocus = nil
khusus.introPlayer = nil
khusus.introToken = 0
khusus.readAloud = { engine = nil, token = 0 }

khusus.readTriggers = pickLogic({
    ["baca ulang"] = true,
    ["baca ulang tulisan"] = true,
    ["bacakan tulisan"] = true,
    ["bacakan ulang"] = true
}, {
    ["read back"] = true,
    ["read it back"] = true,
    ["read text back"] = true,
    ["read the text"] = true
})

function khusus.matchRead(list)
    if list == nil then
        return false
    end
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        if khusus.readTriggers[spoken] == true then
            return true
        end
    end
    return false
end

function khusus.stopReadAloud()
    local state = khusus.readAloud
    state.token = state.token + 1
    local engine = state.engine
    state.engine = nil
    if engine ~= nil then
        pcall(function()
            engine.stop()
        end)
        pcall(function()
            engine.shutdown()
        end)
    end
end

function khusus.splitSentences(text)
    local marked = tostring(text):gsub("\r", "\n")
    marked = marked:gsub("([%.%!%?]+)%s+", "%1\n")
    local sentences = {}
    for piece in (marked .. "\n"):gmatch("(.-)\n") do
        local sentence = khusus.trim(piece)
        if sentence ~= "" then
            sentences[#sentences + 1] = sentence
        end
    end
    return sentences
end

function khusus.startReadAloud(sentences)
    khusus.stopReadAloud()
    local state = khusus.readAloud
    local token = state.token
    local intro = T("Membaca ", "Reading ") .. #sentences .. T(" kalimat.", " sentences.")
    local total = #intro
    for _, sentence in ipairs(sentences) do
        total = total + #sentence
    end
    local estimate = 2500 + total * 110
    khusus.autoTypeHold = System.currentTimeMillis() + estimate
    local engine = nil
    local created = pcall(function()
        engine = TextToSpeech(this, TextToSpeech.OnInitListener{
            onInit = function(status)
                if token ~= state.token or engine == nil then
                    return
                end
                if status ~= TextToSpeech.SUCCESS then
                    khusus.stopReadAloud()
                    khusus.speakAfterMicrophone(T("Mesin suara TTS gagal disiapkan.", "The TTS voice engine could not be prepared."))
                    return
                end
                pcall(function()
                    local result = engine.setLanguage(uiIndonesian and Locale("id", "ID") or Locale.getDefault())
                    if result < 0 then
                        engine.setLanguage(Locale.getDefault())
                    end
                end)
                khusus.handler.postDelayed(function()
                    if token ~= state.token then
                        return
                    end
                    local queue = { intro }
                    for _, sentence in ipairs(sentences) do
                        queue[#queue + 1] = sentence
                    end
                    for i, part in ipairs(queue) do
                        local spoken = pcall(function()
                            engine.speak(part, TextToSpeech.QUEUE_ADD, nil, "bacaulang" .. i)
                        end)
                        if not spoken then
                            pcall(function()
                                engine.speak(part, TextToSpeech.QUEUE_ADD, nil)
                            end)
                        end
                    end
                    khusus.handler.postDelayed(function()
                        if token == state.token then
                            khusus.stopReadAloud()
                        end
                    end, estimate)
                end, 500)
            end
        })
    end)
    if not created or engine == nil then
        khusus.speakAfterMicrophone(T("Mesin suara TTS gagal disiapkan.", "The TTS voice engine could not be prepared."))
        return
    end
    state.engine = engine
end

function khusus.readByVoice()
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        khusus.speakAfterMicrophone(T("Tidak ada teks yang fokus.", "No text is focused."))
        return
    end
    local isPassword = false
    pcall(function()
        isPassword = node.isPassword() == true
    end)
    if isPassword then
        khusus.speakAfterMicrophone(T("Kotak sandi tidak dibacakan.", "A password box is not read aloud."))
        return
    end
    local hinted = false
    pcall(function()
        hinted = node.isShowingHintText() == true
    end)
    local readable, current = pcall(function()
        return tostring(node.getText() or "")
    end)
    if not readable or hinted or current:match("%S") == nil then
        khusus.speakAfterMicrophone(T("Kotak teks kosong.", "The text box is empty."))
        return
    end
    local sentences = khusus.splitSentences(current)
    if #sentences == 0 then
        khusus.speakAfterMicrophone(T("Kotak teks kosong.", "The text box is empty."))
        return
    end
    khusus.startReadAloud(sentences)
end

khusus.writePrefixes = pickLogic({ "tulis", "tuliskan" }, {})
khusus.writeBareNames = pickLogic({ "doa", "ucapan" }, {})
khusus.writeEntries = pickLogic({
    {
        label = "Salam",
        names = { "salam", "salam islam", "assalamualaikum", "assalamu alaikum", "assalamu alaikum warahmatullahi wabarakatuh" }
    },
    {
        label = "Jawaban salam",
        names = { "jawab salam", "jawaban salam", "balas salam", "waalaikumsalam", "wa alaikum salam" }
    },
    {
        label = "Basmalah",
        names = { "basmalah", "bismillah", "doa basmalah" }
    },
    {
        label = "Doa sebelum makan",
        names = { "doa sebelum makan", "doa makan", "doa mau makan" }
    },
    {
        label = "Doa sesudah makan",
        names = { "doa sesudah makan", "doa setelah makan", "doa selesai makan" }
    },
    {
        label = "Doa sebelum tidur",
        names = { "doa sebelum tidur", "doa tidur", "doa mau tidur" }
    },
    {
        label = "Doa bangun tidur",
        names = { "doa bangun tidur", "doa sesudah tidur", "doa setelah tidur" }
    },
    {
        label = "Doa keluar rumah",
        names = { "doa keluar rumah", "doa mau keluar rumah", "doa berangkat" }
    },
    {
        label = "Doa naik kendaraan",
        names = { "doa naik kendaraan", "doa kendaraan", "doa bepergian", "doa perjalanan" }
    },
    {
        label = "Doa masuk masjid",
        names = { "doa masuk masjid" }
    },
    {
        label = "Doa keluar masjid",
        names = { "doa keluar masjid" }
    },
    {
        label = "Doa sesudah wudhu",
        names = { "doa sesudah wudhu", "doa setelah wudhu", "doa wudhu" }
    },
    {
        label = "Doa sapu jagat",
        names = { "doa sapu jagat", "doa kebaikan dunia akhirat" }
    },
    {
        label = "Doa untuk orang tua",
        names = { "doa orang tua", "doa untuk orang tua", "doa kedua orang tua" }
    },
    {
        label = "Doa sebelum belajar",
        names = { "doa sebelum belajar", "doa belajar", "doa menuntut ilmu" }
    },
    {
        label = "Doa untuk orang sakit",
        names = { "doa orang sakit", "doa untuk orang sakit", "doa menjenguk orang sakit" }
    },
    {
        label = "Ucapan belasungkawa",
        names = { "ucapan belasungkawa", "ucapan duka", "ucapan duka cita", "doa musibah", "doa belasungkawa" }
    },
    {
        label = "Ucapan pernikahan",
        names = { "ucapan pernikahan", "ucapan menikah", "doa pernikahan", "doa pengantin" }
    },
    {
        label = "Ucapan Idul Fitri",
        names = { "ucapan idul fitri", "ucapan lebaran", "ucapan hari raya idul fitri", "ucapan hari raya" }
    },
    {
        label = "Ucapan Idul Adha",
        names = { "ucapan idul adha", "ucapan hari raya idul adha", "ucapan hari raya kurban" }
    },
    {
        label = "Ucapan Ramadan",
        names = { "ucapan ramadan", "ucapan ramadhan", "ucapan bulan puasa", "ucapan puasa" }
    },
    {
        label = "Ucapan Jumat berkah",
        names = { "ucapan jumat", "ucapan jumat berkah", "ucapan hari jumat", "jumat berkah" }
    },
    {
        label = "Ucapan tahun baru Islam",
        names = { "ucapan tahun baru islam", "ucapan tahun baru hijriah", "ucapan satu muharam", "ucapan muharam" }
    },
    {
        label = "Ucapan Maulid Nabi",
        names = { "ucapan maulid", "ucapan maulid nabi", "ucapan maulid nabi muhammad" }
    }
}, {})

khusus.writeLookup = {}
khusus.writeBare = {}
for _, prefix in ipairs(khusus.writePrefixes) do
    for _, name in ipairs(khusus.writeBareNames) do
        khusus.writeBare[prefix .. " " .. name] = true
    end
    for _, entry in ipairs(khusus.writeEntries) do
        for _, name in ipairs(entry.names) do
            khusus.writeLookup[prefix .. " " .. name] = entry
        end
    end
end

function khusus.matchWrite(list)
    if list == nil then
        return nil
    end
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        local entry = khusus.writeLookup[spoken]
        if entry ~= nil then
            return entry
        end
        if khusus.writeBare[spoken] == true then
            return "help"
        end
    end
    return nil
end

function khusus.writeInsert(text, remaining, done)
    local inserted = pcall(function()
        service.insertText(service.getEditText(), text)
    end)
    if inserted then
        done(true)
        return
    end
    if remaining <= 0 then
        done(false)
        return
    end
    local scheduled = pcall(function()
        khusus.handler.postDelayed(function()
            khusus.writeInsert(text, remaining - 1, done)
        end, 250)
    end)
    if not scheduled then
        done(false)
    end
end

function khusus.doaLoad(entry)
    if type(rawget(entry, "arab")) == "string" then
        return true
    end
    local details = khusus.tabelEval("tabel_doa_salam.lua")
    local item = nil
    if details ~= nil then
        item = details[entry.label]
    end
    if type(item) ~= "table" or type(item.arab) ~= "string" or type(item.latin) ~= "string" or type(item.arti) ~= "string" then
        return false
    end
    entry.arab = item.arab
    entry.latin = item.latin
    entry.arti = item.arti
    return true
end

function khusus.writeByVoice(entry)
    if entry == "help" then
        khusus.speakAfterMicrophone(T("Sebutkan nama doa atau ucapannya, misalnya tulis salam, tulis doa sebelum makan, atau tulis ucapan idul fitri.", "Say the name of the prayer or greeting."))
        return
    end
    if not khusus.doaLoad(entry) then
        khusus.speakAfterMicrophone(T("File tabel_doa_salam.lua tidak ditemukan atau rusak. Letakkan file tersebut di folder yang sama dengan main.lua.", "The file tabel_doa_salam.lua was not found or is damaged. Put it in the same folder as main.lua."))
        return
    end
    local text = entry.arab .. "\n" .. entry.latin .. "\n" .. entry.arti
    if getFlag("spasi_setelah_teks", false) then
        text = text .. " "
    end
    if getFlag("baris_baru") then
        text = text .. "\n"
    end
    khusus.writeInsert(text, 3, function(inserted)
        if inserted then
            khusus.lastInserted = text
            khusus.speakAfterMicrophone(entry.label .. T(" ditulis.", " written."))
        elseif khusus.copyToClipboard(text) then
            khusus.speakAfterMicrophone(T("Pesan tersalin ke papan klip.", "Message copied to the clipboard."))
        else
            khusus.speakAfterMicrophone(T("Teks gagal dimasukkan.", "The text could not be inserted."))
        end
    end)
end

khusus.deleteTriggers = pickLogic({
    ["hapus semua"] = "all",
    ["hapus sebagian"] = "part"
}, {
    ["delete all"] = "all",
    ["delete part"] = "part",
    ["delete some"] = "part"
})

khusus.undoWindowMs = 60000
khusus.undoTriggers = pickLogic({
    ["batalkan hapus"] = true,
    ["urungkan hapus"] = true
}, {
    ["undo delete"] = true,
    ["undo deletion"] = true
})

khusus.translateTextWord = pickLogic("terjemahkan", "translate")
khusus.translateTextTriggers = pickLogic({
    ["indonesia"] = "id",
    ["inggris"] = "en",
    ["spanyol"] = "es",
    ["belanda"] = "nl",
    ["arab"] = "ar",
    ["portugis"] = "pt",
    ["jawa"] = "jw",
    ["sunda"] = "su"
}, {
    ["indonesian"] = "id",
    ["english"] = "en",
    ["spanish"] = "es",
    ["dutch"] = "nl",
    ["arabic"] = "ar",
    ["portuguese"] = "pt",
    ["javanese"] = "jw",
    ["sundanese"] = "su",
    ["french"] = "fr",
    ["german"] = "de",
    ["italian"] = "it",
    ["japanese"] = "ja",
    ["korean"] = "ko",
    ["chinese"] = "zh-CN",
    ["russian"] = "ru",
    ["hindi"] = "hi",
    ["turkish"] = "tr"
})
khusus.translateTextFillers = pickLogic({ "tulisan", "teks", "ke", "dalam", "bahasa" }, { "text", "to", "into", "the", "language", "in" })

khusus.languages = {
    { name = T("Indonesia", "Indonesian"), code = "id" }, { name = T("Inggris", "English"), code = "en" }, { name = T("Jawa", "Javanese"), code = "jw" },
    { name = T("Sunda", "Sundanese"), code = "su" }, { name = T("Arab", "Arabic"), code = "ar" }, { name = T("Jepang", "Japanese"), code = "ja" },
    { name = T("Korea", "Korean"), code = "ko" }, { name = T("Mandarin", "Mandarin"), code = "zh-CN" }, { name = T("Rusia", "Russian"), code = "ru" },
    { name = T("Jerman", "German"), code = "de" }, { name = T("Prancis", "French"), code = "fr" }, { name = T("Spanyol", "Spanish"), code = "es" },
    { name = T("Portugal/Brazil", "Portuguese/Brazil"), code = "pt" }, { name = T("Italia", "Italian"), code = "it" }, { name = T("Belanda", "Dutch"), code = "nl" },
    { name = "Hindi", code = "hi" }, { name = T("Thailand", "Thai"), code = "th" }, { name = T("Vietnam", "Vietnamese"), code = "vi" },
    { name = T("Turki", "Turkish"), code = "tr" }, { name = T("Filipina", "Filipino"), code = "tl" }, { name = T("Melayu", "Malay"), code = "ms" },
    { name = "Bengali", code = "bn" }, { name = "Urdu", code = "ur" }, { name = T("Persia", "Persian"), code = "fa" }
}

do
    local jsonLoaded, jsonModule = pcall(function()
        return require("cjson")
    end)
    if jsonLoaded then
        khusus.json = jsonModule
    end
end

function khusus.trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$")
end

function khusus.normalizeToken(s)
    s = tostring(s or "")
    s = s:gsub("[%z\1-\31]", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s:lower()
end

function khusus.escape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\r", "")
    s = s:gsub("\n", "\\n")
    s = s:gsub("|", "\\p")
    return s
end

function khusus.unescape(s)
    local result = tostring(s or ""):gsub("\\(.)", function(c)
        if c == "n" then
            return "\n"
        elseif c == "p" then
            return "|"
        end
        return c
    end)
    return result
end

function khusus.validPattern(pattern)
    local ok = pcall(string.find, "", pattern)
    return ok
end

function khusus.readLegacy(name)
    local ok, lines = pcall(function()
        local file = File(khusus.legacyDir .. name)
        if not file.exists() then
            return nil
        end
        local reader = BufferedReader(InputStreamReader(FileInputStream(file), "UTF-8"))
        local collected = {}
        while true do
            local line = reader.readLine()
            if line == nil then
                break
            end
            collected[#collected + 1] = tostring(line)
        end
        reader.close()
        return collected
    end)
    if ok then
        return lines
    end
    return nil
end

function khusus.saveMacros()
    local lines = {}
    for _, item in ipairs(khusus.macros) do
        lines[#lines + 1] = khusus.escape(item.trigger) .. "|" .. khusus.escape(item.content)
    end
    getPrefs().edit().putString("makro_data", table.concat(lines, "\n")).apply()
end

function khusus.getMacros()
    if khusus.macros ~= nil then
        return khusus.macros
    end
    khusus.macros = {}
    local raw = getPrefs().getString("makro_data", nil)
    if raw ~= nil then
        for line in tostring(raw):gmatch("[^\n]+") do
            local trigger, content = line:match("^(.-)|(.*)$")
            if trigger ~= nil then
                trigger = khusus.trim(khusus.unescape(trigger))
                if trigger ~= "" and #khusus.macros < khusus.maxMacro then
                    khusus.macros[#khusus.macros + 1] = { trigger = trigger, content = khusus.unescape(content) }
                end
            end
        end
        return khusus.macros
    end
    local legacy = khusus.readLegacy("macro.txt")
    if legacy ~= nil then
        for _, line in ipairs(legacy) do
            local trigger, content = line:match("^(.-)%|%|(.*)$")
            if trigger ~= nil and khusus.trim(trigger) ~= "" and #khusus.macros < khusus.maxMacro then
                khusus.macros[#khusus.macros + 1] = { trigger = khusus.trim(trigger), content = tostring(content or "") }
            end
        end
    end
    khusus.saveMacros()
    return khusus.macros
end

function khusus.saveWords()
    local lines = {}
    for _, item in ipairs(khusus.words) do
        local flag = "0"
        if item.isRegex then
            flag = "1"
        end
        lines[#lines + 1] = khusus.escape(item.origin) .. "|" .. khusus.escape(item.replacement) .. "|" .. flag
    end
    getPrefs().edit().putString("kamus_data", table.concat(lines, "\n")).apply()
end

function khusus.getWords()
    if khusus.words ~= nil then
        return khusus.words
    end
    khusus.words = {}
    local raw = getPrefs().getString("kamus_data", nil)
    if raw ~= nil then
        for line in tostring(raw):gmatch("[^\n]+") do
            local origin, replacement, flag = line:match("^(.-)|(.-)|([01])$")
            if origin ~= nil then
                origin = khusus.trim(khusus.unescape(origin))
                if origin ~= "" then
                    khusus.words[#khusus.words + 1] = {
                        origin = origin,
                        replacement = khusus.unescape(replacement),
                        isRegex = (flag == "1")
                    }
                end
            end
        end
        return khusus.words
    end
    local legacy = khusus.readLegacy("kamus.txt")
    if legacy ~= nil then
        for _, line in ipairs(legacy) do
            local origin, rest = line:match("^(.-)%|(.*)$")
            if origin ~= nil and khusus.trim(origin) ~= "" then
                local replacement, flag = rest:match("^(.-)%|([01])$")
                if replacement == nil then
                    replacement = rest
                    flag = "0"
                end
                khusus.words[#khusus.words + 1] = {
                    origin = khusus.trim(origin),
                    replacement = khusus.trim(replacement),
                    isRegex = (flag == "1")
                }
            end
        end
    end
    khusus.saveWords()
    return khusus.words
end

function khusus.expandMacro(content)
    local raw = tostring(content or "")
    if not raw:find("{", 1, true) then
        return raw
    end
    local ok, result = pcall(function()
        local days = pickLogic(
            { "Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu" },
            { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" })
        local months = pickLogic(
            { "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember" },
            { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" })
        local d = os.date("*t", os.time())
        local values = {
            tanggal = d.day .. " " .. months[d.month] .. " " .. d.year,
            jam = string.format(pickLogic("%02d.%02d", "%02d:%02d"), d.hour, d.min),
            hari = days[d.wday],
            bulan = months[d.month],
            tahun = tostring(d.year),
        }
        local text = raw
        text = (text:gsub("{{(%a+)}}", function(name)
            if values[name:lower()] ~= nil then
                return "\1" .. name .. "\2"
            end
        end))
        text = (text:gsub("{(%a+)}", function(name)
            return values[name:lower()]
        end))
        text = (text:gsub("\1(%a+)\2", "{%1}"))
        return text
    end)
    if ok and type(result) == "string" then
        return result
    end
    return raw
end

function khusus.applyMacro(text)
    if not getFlag("makro_aktif") then
        return text, false
    end
    local normalized = khusus.normalizeToken(text)
    for _, item in ipairs(khusus.getMacros()) do
        if khusus.normalizeToken(item.trigger) == normalized then
            return khusus.expandMacro(item.content), true
        end
    end
    return text, false
end

function khusus.applyDictionary(text, force)
    if text == nil then
        return text
    end
    if not force and not getFlag("kamus_aktif") then
        return text
    end
    local processed = tostring(text)
    for _, item in ipairs(khusus.getWords()) do
        local origin = item.origin
        local replacement = item.replacement or ""
        if origin ~= nil and origin ~= "" then
            if item.isRegex then
                local ok, result = pcall(string.gsub, processed, origin, replacement)
                if ok and result then
                    processed = result
                end
            elseif origin:lower() ~= replacement:lower() then
                local lowerText = processed:lower()
                local lowerOrigin = origin:lower()
                local checkStart = lowerOrigin:match("^[%w\128-\255]") ~= nil
                local checkEnd = lowerOrigin:match("[%w\128-\255]$") ~= nil
                local startPos = 1
                while true do
                    local s, e = lowerText:find(lowerOrigin, startPos, true)
                    if not s then
                        break
                    end
                    local wholeWord = true
                    if checkStart and s > 1 and lowerText:sub(s - 1, s - 1):match("[%w\128-\255]") ~= nil then
                        wholeWord = false
                    end
                    if wholeWord and checkEnd and e < #lowerText and lowerText:sub(e + 1, e + 1):match("[%w\128-\255]") ~= nil then
                        wholeWord = false
                    end
                    if wholeWord then
                        processed = processed:sub(1, s - 1) .. replacement .. processed:sub(e + 1)
                        lowerText = processed:lower()
                        startPos = s + #replacement
                    else
                        startPos = s + 1
                    end
                end
            end
        end
    end
    return processed
end

function khusus.capitalizeFirst(text)
    if not text then
        return ""
    end
    local result = text:gsub("^%l", string.upper)
    return result
end

function khusus.normalizeOkay(text)
    local result = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") then
            return token
        end
        local fixed = token:gsub("%f[%a][Oo][Kk][Aa][Yy]%f[%A]", function(word)
            return khusus.matchCase(word, "ok")
        end)
        return fixed
    end)
    return result
end

function khusus.correctEnglish(text)
    local tag = getLanguageTag()
    if type(tag) == "string" and tag:sub(1, 2) == "en" then
        return khusus.normalizeOkay(text)
    end
    return text
end

function khusus.keepOkAfterTranslate(source, translated, targetLang)
    if khusus.baseCode(targetLang) ~= "en" then
        return translated
    end
    local count = 0
    for _ in tostring(source or ""):gmatch("%f[%a][Oo][Kk]%f[%A]") do
        count = count + 1
    end
    for _ in tostring(source or ""):gmatch("%f[%a][Oo][Kk][Ee]%f[%A]") do
        count = count + 1
    end
    if count == 0 then
        return translated
    end
    local replaced = 0
    local result = tostring(translated):gsub("%f[%a][Oo][Kk][Aa][Yy]%f[%A]", function(word)
        if replaced >= count then
            return nil
        end
        replaced = replaced + 1
        return khusus.matchCase(word, "ok")
    end)
    return result
end

function khusus.addPunctuation(text)
    if not text then
        return ""
    end
    text = tostring(text)
    if text == "" then
        return ""
    end
    local body, tail = text:match("^(.-)(%s*)$")
    if body == "" or body:match("[%.%!%?]$") then
        return text
    end
    return body .. "." .. tail
end

function khusus.safeStage(stage, text, ...)
    local ok, value = pcall(stage, text, ...)
    if ok and type(value) == "string" then
        return value
    end
    return text
end

khusus.fillerWordsId = {
    ["eh"] = true, ["ehh"] = true, ["ehhh"] = true,
    ["em"] = true, ["emm"] = true, ["emmm"] = true, ["emmmm"] = true,
    ["ehm"] = true, ["ehmm"] = true, ["ehmmm"] = true
}

khusus.fillerWordsEn = {
    ["um"] = true, ["umm"] = true, ["ummm"] = true,
    ["uhm"] = true, ["uhmm"] = true, ["erm"] = true
}

khusus.repeatWordsId = {
    ["saya"] = true, ["aku"] = true, ["dia"] = true, ["ia"] = true, ["anda"] = true,
    ["mereka"] = true, ["kami"] = true, ["gue"] = true, ["gua"] = true, ["lu"] = true, ["lo"] = true,
    ["yang"] = true, ["dan"] = true, ["atau"] = true, ["di"] = true, ["ke"] = true,
    ["dari"] = true, ["untuk"] = true, ["dengan"] = true, ["pada"] = true,
    ["karena"] = true, ["tapi"] = true, ["tetapi"] = true, ["jadi"] = true, ["jika"] = true,
    ["bahwa"] = true, ["supaya"] = true, ["agar"] = true, ["sehingga"] = true, ["ketika"] = true,
    ["akan"] = true, ["harus"] = true, ["masih"] = true, ["juga"] = true, ["ingin"] = true,
    ["perlu"] = true, ["kemudian"] = true, ["lalu"] = true
}

khusus.repeatWordsEn = {
    ["i"] = true, ["the"] = true, ["a"] = true, ["an"] = true, ["to"] = true, ["and"] = true,
    ["of"] = true, ["in"] = true, ["we"] = true, ["you"] = true, ["they"] = true, ["he"] = true,
    ["she"] = true, ["my"] = true, ["but"] = true, ["it"] = true, ["is"] = true, ["are"] = true,
    ["was"] = true, ["for"] = true, ["with"] = true, ["on"] = true, ["at"] = true, ["as"] = true
}

function khusus.cleanFillerSets()
    if logicIndonesian then
        return khusus.fillerWordsId, khusus.repeatWordsId
    end
    local code = tostring(getLanguageTag() or ""):sub(1, 2):lower()
    if code == "en" then
        return khusus.fillerWordsEn, khusus.repeatWordsEn
    end
    return nil, nil
end

function khusus.cleanFillers(text)
    local fillers, repeats = khusus.cleanFillerSets()
    if fillers == nil then
        return text
    end
    local tokens = {}
    for space, word in text:gmatch("(%s*)(%S+)") do
        local lead, core, tail = word:match("^([^%w]*)(%w+)([^%w]*)$")
        tokens[#tokens + 1] = { space = space, word = word, lead = lead, core = core, tail = tail }
    end
    if #tokens == 0 then
        return text
    end
    local firstSpace = tokens[1].space
    local kept = {}
    local carryLead = ""
    local carrySpace = nil
    for _, token in ipairs(tokens) do
        local isFiller = false
        if token.core ~= nil and fillers[token.core:lower()] == true then
            if #token.core < 2 or token.core ~= token.core:upper() then
                isFiller = true
            end
        end
        if isFiller then
            if token.space:find("\n") then
                carrySpace = token.space
            end
            carryLead = carryLead .. token.lead
            local marks = token.tail:match("[%.%?!]+")
            local previous = kept[#kept]
            if marks ~= nil and previous ~= nil and previous.core ~= nil and previous.tail:find("[%.%?!]") == nil then
                previous.tail = previous.tail:gsub("[,;:]+$", "") .. marks
            end
        else
            if carryLead ~= "" then
                if token.core ~= nil then
                    token.lead = carryLead .. token.lead
                else
                    token.word = carryLead .. token.word
                end
            end
            carryLead = ""
            if carrySpace ~= nil and token.space:find("\n") == nil then
                token.space = carrySpace
            end
            carrySpace = nil
            kept[#kept + 1] = token
        end
    end
    if #kept == 0 then
        return ""
    end
    local merged = {}
    for _, token in ipairs(kept) do
        local previous = merged[#merged]
        local duplicate = false
        if previous ~= nil and token.core ~= nil and previous.core ~= nil and repeats[token.core:lower()] == true then
            if previous.core:lower() == token.core:lower() and previous.tail:match("^[,;:]*$") ~= nil and token.lead == "" and token.space:find("\n") == nil then
                duplicate = true
            end
        end
        if duplicate then
            previous.tail = token.tail
        else
            merged[#merged + 1] = token
        end
    end
    merged[1].space = firstSpace
    local parts = {}
    for _, token in ipairs(merged) do
        if token.core ~= nil then
            parts[#parts + 1] = token.space .. token.lead .. token.core .. token.tail
        else
            parts[#parts + 1] = token.space .. token.word
        end
    end
    return table.concat(parts) .. text:match("%s*$")
end

function khusus.markText(text, pauseEnabled, useAutoMarks, pauses, voicedMs, pauseIndex, formatting)
    local words = splitWords(text)
    local boundaries = {}
    local pauseMarks = {}
    if useAutoMarks then
        correctRecognizerMarks(words)
        text = table.concat(words, " ")
    end
    if pauseEnabled then
        boundaries, pauseMarks = placePauses(words, pauses, voicedMs, pauseMinWords[pauseIndex])
    end
    if useAutoMarks and formatting then
        khusus.splitAtLineCommands(words, boundaries)
    end
    addLinguisticMarks(words, boundaries, pauseIndex, useAutoMarks)
    local segmentStart = markSentences(words, boundaries, useAutoMarks, pauseMarks)
    local trailing = sentenceMark(words, segmentStart, #words, useAutoMarks, boundaries)
    text = buildText(text, boundaries)
    if trailing ~= "" and allowsTrailing(text) then
        text = text .. trailing
    end
    return text
end

khusus.spokenMarks = {
    ["tanda koma"] = ",",
    ["tanda titik"] = ".",
    ["tanda tanya"] = "?",
    ["tanda seru"] = "!",
    ["tanda titik dua"] = ":",
    ["tanda titik koma"] = ";"
}

function khusus.spokenMarkAt(words, index, total)
    for length = math.min(3, total - index + 1), 2, -1 do
        local parts = {}
        for offset = 0, length - 1 do
            parts[#parts + 1] = plainWord(words[index + offset])
        end
        local mark = khusus.spokenMarks[table.concat(parts, " ")]
        if mark ~= nil then
            return length, mark
        end
    end
    return 0, nil
end

khusus.spokenFormats = {
    ["baris baru"] = "line",
    ["paragraf baru"] = "paragraph",
    ["tanda kutip buka"] = "open",
    ["tanda kutip tutup"] = "close",
    ["huruf kapital kata berikutnya"] = "capital"
}

function khusus.formatWord(word)
    return (tostring(word or ""):lower():match("^(%a+)[,;:%.!%?]*$")) or ""
end

function khusus.spokenFormatAt(words, index, total)
    for length = math.min(4, total - index + 1), 2, -1 do
        local parts = {}
        for offset = 0, length - 1 do
            parts[#parts + 1] = khusus.formatWord(words[index + offset])
        end
        local kind = khusus.spokenFormats[table.concat(parts, " ")]
        if kind ~= nil then
            return length, kind
        end
    end
    return 0, nil
end

function khusus.splitAtLineCommands(words, boundaries)
    local total = #words
    local index = 1
    while index <= total do
        local length, kind = khusus.spokenFormatAt(words, index, total)
        if length > 0 and (kind == "line" or kind == "paragraph") then
            local last = index + length - 1
            if index > 1 then
                boundaries[index - 1] = "."
            end
            if last < total then
                boundaries[last] = "."
            end
            index = last + 1
        else
            index = index + 1
        end
    end
end

function khusus.capitalizeWord(word)
    local result = word:gsub("^([^%w]*)(%a)", function(lead, letter)
        return lead .. letter:upper()
    end)
    return result
end

function khusus.mergeMarks(previous, carried)
    if carried == "" then
        return previous
    end
    local ending = previous:match("[,;:%.!%?]+$")
    if ending == nil then
        return previous .. carried
    end
    if ending:find("[%.!%?]") ~= nil then
        return previous
    end
    if carried:find("[%.!%?]") ~= nil then
        return previous:sub(1, #previous - #ending) .. carried
    end
    return previous
end

function khusus.applySpokenMarks(text)
    if not logicIndonesian then
        return text
    end
    local words = splitWords(text)
    local total = #words
    local out = {}
    local gaps = {}
    local breaks = 0
    local prefix = ""
    local capital = false
    local explicit = false
    local index = 1

    local function push(token)
        local gap = " "
        if #out == 0 then
            gap = ""
        end
        if breaks > 0 then
            gap = string.rep("\n", breaks)
            breaks = 0
        end
        out[#out + 1] = prefix .. token
        gaps[#out] = gap
        prefix = ""
        explicit = false
    end

    local function pushWord(word)
        if capital then
            word = khusus.capitalizeWord(word)
            capital = false
        end
        push(word)
    end

    while index <= total do
        local formatLength, kind = khusus.spokenFormatAt(words, index, total)
        if kind == "capital" and index == 2 and khusus.formatWord(words[1]) == "gunakan" then
            formatLength = 0
        end
        if formatLength > 0 then
            local carried = words[index + formatLength - 1]:match("[,;:%.!%?]+$") or ""
            if kind == "line" or kind == "paragraph" then
                if breaks == 0 and #out > 0 and not explicit then
                    out[#out] = (out[#out]:gsub("[,;:]+$", ""))
                end
                if kind == "line" then
                    breaks = breaks + 1
                else
                    breaks = breaks + 2
                end
            elseif kind == "open" then
                if prefix == "" then
                    prefix = "\""
                end
            elseif kind == "close" then
                if prefix ~= "" or #out == 0 or breaks > 0 then
                    push("\"")
                else
                    out[#out] = khusus.mergeMarks(out[#out], carried) .. "\""
                end
            else
                capital = true
            end
            index = index + formatLength
        else
            local length, mark = khusus.spokenMarkAt(words, index, total)
            if length > 0 and #out > 0 and breaks == 0 and prefix == "" then
                out[#out] = out[#out]:gsub("[,;:%.!%?]+$", "") .. mark
                explicit = true
                index = index + length
            else
                pushWord(words[index])
                index = index + 1
            end
        end
    end

    if prefix ~= "" then
        push("")
    end
    local parts = {}
    for position, token in ipairs(out) do
        parts[#parts + 1] = gaps[position] .. token
    end
    return table.concat(parts) .. string.rep("\n", breaks)
end

khusus.addressJoiners = { titik = ".", underscore = "_", strip = "-" }

function khusus.addressTokens(text)
    local tokens = {}
    for first, token, after in text:gmatch("()(%S+)()") do
        local lead, core, trail = token:match("^([^%w]*)(%w*)([^%w]*)$")
        tokens[#tokens + 1] = {
            first = first,
            last = after - 1,
            lead = lead or "",
            core = core and core:lower() or "",
            trail = trail or "",
            plain = core ~= nil and core ~= ""
        }
    end
    return tokens
end

function khusus.addressCore(tokens, index)
    local token = tokens[index]
    if token == nil then
        return ""
    end
    return token.core
end

function khusus.addressWord(token)
    return token ~= nil and token.plain and khusus.addressJoiners[token.core] == nil and token.core ~= "at"
end

function khusus.addressLinked(text, tokens, from, to)
    for index = from, to - 1 do
        local current = tokens[index]
        if current.trail:match("^[,;:%.!%?]*$") == nil or tokens[index + 1].lead ~= "" then
            return false
        end
        if text:sub(current.last + 1, tokens[index + 1].first - 1):find("\n", 1, true) ~= nil then
            return false
        end
    end
    return true
end

function khusus.addressClaim(tokens, claimed, found, first, last, value)
    for index = first, last do
        claimed[index] = true
    end
    found[#found + 1] = {
        from = tokens[first].first + #tokens[first].lead,
        to = tokens[last].last - #tokens[last].trail,
        value = value
    }
end

function khusus.addressLocal(text, tokens, at, claimed)
    local first = at - 1
    local token = tokens[first]
    if claimed[first] or not khusus.addressWord(token) then
        return nil
    end
    local value = token.core
    local previous = tokens[first - 1]
    if value:match("^%d+$") ~= nil and previous ~= nil and not claimed[first - 1] and khusus.addressWord(previous)
        and previous.core:match("^%a") ~= nil and khusus.addressLinked(text, tokens, first - 1, first) then
        value = previous.core .. value
        first = first - 1
    end
    while tokens[first].lead == "" do
        local joiner = tokens[first - 1]
        local symbol = nil
        local width = 0
        if joiner ~= nil and joiner.plain then
            symbol = khusus.addressJoiners[joiner.core]
            width = 1
            if symbol == nil and joiner.core == "bawah" and khusus.addressCore(tokens, first - 2) == "garis" then
                symbol = "_"
                width = 2
            end
        end
        local wordIndex = first - 1 - width
        if symbol == nil or wordIndex < 1 or claimed[wordIndex] or not khusus.addressWord(tokens[wordIndex])
            or not khusus.addressLinked(text, tokens, wordIndex, first) then
            break
        end
        value = tokens[wordIndex].core .. symbol .. value
        first = wordIndex
    end
    return first, value
end

function khusus.addressDomain(text, tokens, start, claimed, allowLead)
    local labels = {}
    local ends = {}
    local index = start
    while tokens[index] ~= nil and not claimed[index] do
        local token = tokens[index]
        local label = token.core
        local width = 1
        if label == "w" and khusus.addressCore(tokens, index + 1) == "w" and khusus.addressCore(tokens, index + 2) == "w"
            and khusus.addressLinked(text, tokens, index, index + 2) then
            label = "www"
            width = 3
        end
        if not khusus.addressWord(token) or (token.lead ~= "" and not (allowLead and index == start)) then
            break
        end
        labels[#labels + 1] = label
        ends[#labels] = index + width - 1
        if khusus.addressCore(tokens, index + width) ~= "titik" or tokens[index + width + 1] == nil
            or not khusus.addressLinked(text, tokens, index, index + width + 1) then
            break
        end
        index = index + width + 1
    end
    while #labels > 0 and addressTopLevels:find(" " .. labels[#labels] .. " ", 1, true) == nil do
        labels[#labels] = nil
    end
    if #labels < 2 then
        return nil
    end
    return table.concat(labels, "."), ends[#labels], labels
end

function khusus.addressEmails(text, tokens, claimed, found)
    for at = 2, #tokens do
        local token = tokens[at]
        if token.core == "at" and token.plain and token.lead == "" and not claimed[at] then
            local first, value = khusus.addressLocal(text, tokens, at, claimed)
            if first ~= nil then
                local domain, last = khusus.addressDomain(text, tokens, at + 1, claimed, false)
                if domain ~= nil and khusus.addressLinked(text, tokens, first, last) then
                    khusus.addressClaim(tokens, claimed, found, first, last, value .. "@" .. domain)
                end
            end
        end
    end
end

function khusus.addressSchemeEnd(tokens, index)
    local scheme = khusus.addressCore(tokens, index)
    if scheme ~= "http" and scheme ~= "https" then
        return nil
    end
    local position = index + 1
    if khusus.addressCore(tokens, position) == "titik" and khusus.addressCore(tokens, position + 1) == "dua" then
        position = position + 2
    end
    if khusus.addressSlashWidth(tokens, position) == 2 and khusus.addressSlashWidth(tokens, position + 2) == 2 then
        return position + 4
    end
    if khusus.addressCore(tokens, position) == "slash" and khusus.addressCore(tokens, position + 1) == "slash" then
        return position + 2
    end
    return nil
end

function khusus.addressSlashWidth(tokens, index)
    local core = khusus.addressCore(tokens, index)
    if core == "garis" and khusus.addressCore(tokens, index + 1) == "miring" then
        return 2
    end
    if core == "slash" then
        return 1
    end
    return 0
end

function khusus.addressWebs(text, tokens, claimed, found)
    local index = 1
    while index <= #tokens do
        local matched = false
        if not claimed[index] then
            local scheme = nil
            local start = index
            local afterScheme = khusus.addressSchemeEnd(tokens, index)
            if afterScheme ~= nil then
                scheme = tokens[index].core .. "://"
                start = afterScheme
            end
            local domain, last = khusus.addressDomain(text, tokens, start, claimed, scheme == nil)
            if domain ~= nil and khusus.addressLinked(text, tokens, index, last) then
                local value = (scheme or "") .. domain
                local finish = last
                local width = khusus.addressSlashWidth(tokens, finish + 1)
                while width > 0 and not claimed[finish + 1] and khusus.addressLinked(text, tokens, index, finish + width) do
                    value = value .. "/"
                    finish = finish + width
                    local segment = tokens[finish + 1]
                    if segment == nil or claimed[finish + 1] or not khusus.addressWord(segment)
                        or not khusus.addressLinked(text, tokens, index, finish + 1) then
                        break
                    end
                    value = value .. segment.core
                    finish = finish + 1
                    width = khusus.addressSlashWidth(tokens, finish + 1)
                end
                khusus.addressClaim(tokens, claimed, found, index, finish, value)
                index = finish + 1
                matched = true
            end
        end
        if not matched then
            index = index + 1
        end
    end
end

function khusus.addressTrigger(tokens)
    local first = khusus.addressCore(tokens, 1)
    local second = khusus.addressCore(tokens, 2)
    if first == "website" then
        return "web", 1
    end
    if first == "alamat" then
        if second == "website" then
            return "web", 2
        end
        if second == "email" then
            return "email", 2
        end
        return "email", 1
    end
    return nil, 0
end

function khusus.spokenAddresses(text)
    if text:lower():find("titik", 1, true) == nil then
        return text
    end
    local tokens = khusus.addressTokens(text)
    local kind, width = khusus.addressTrigger(tokens)
    if kind == nil or tokens[1].lead ~= "" or #tokens <= width then
        return text
    end
    local claimed = {}
    for index = 1, width do
        claimed[index] = true
    end
    local found = {}
    if kind == "email" then
        khusus.addressEmails(text, tokens, claimed, found)
    else
        khusus.addressWebs(text, tokens, claimed, found)
    end
    if #found == 0 then
        return text
    end
    table.sort(found, function(left, right)
        return left.from < right.from
    end)
    for position = #found, 1, -1 do
        local item = found[position]
        text = text:sub(1, item.from - 1) .. item.value .. text:sub(item.to + 1)
    end
    return text:sub(tokens[width + 1].first)
end

khusus.standardSpelling = {
    ["nafas"] = "napas",
    ["aktifitas"] = "aktivitas",
    ["aktifis"] = "aktivis",
    ["sensitifitas"] = "sensitivitas",
    ["produktifitas"] = "produktivitas",
    ["kreatifitas"] = "kreativitas",
    ["efektifitas"] = "efektivitas",
    ["objektifitas"] = "objektivitas",
    ["subjektifitas"] = "subjektivitas",
    ["relatifitas"] = "relativitas",
    ["propinsi"] = "provinsi",
    ["resiko"] = "risiko",
    ["ijin"] = "izin",
    ["analisa"] = "analisis",
    ["apotik"] = "apotek",
    ["atmosfir"] = "atmosfer",
    ["azas"] = "asas",
    ["kwalitas"] = "kualitas",
    ["kwantitas"] = "kuantitas",
    ["kwitansi"] = "kuitansi",
    ["frekwensi"] = "frekuensi",
    ["sistim"] = "sistem",
    ["metoda"] = "metode",
    ["praktek"] = "praktik",
    ["jaman"] = "zaman",
    ["jadual"] = "jadwal",
    ["hakekat"] = "hakikat",
    ["komplek"] = "kompleks",
    ["kongkrit"] = "konkret",
    ["konkrit"] = "konkret",
    ["nasehat"] = "nasihat",
    ["obyek"] = "objek",
    ["subyek"] = "subjek",
    ["tehnik"] = "teknik",
    ["tehnologi"] = "teknologi",
    ["silahkan"] = "silakan",
    ["sekedar"] = "sekadar",
    ["seksama"] = "saksama",
    ["coklat"] = "cokelat",
    ["cidera"] = "cedera",
    ["supir"] = "sopir",
    ["trampil"] = "terampil",
    ["ketrampilan"] = "keterampilan",
    ["tentram"] = "tenteram",
    ["prosentase"] = "persentase",
    ["silaturrahmi"] = "silaturahmi",
    ["pebruari"] = "Februari",
    ["nopember"] = "November",
    ["karna"] = "karena",
    ["terimakasih"] = "terima kasih",
    ["merubah"] = "mengubah",
    ["dirubah"] = "diubah",
    ["mengkoreksi"] = "mengoreksi",
    ["mengkonsumsi"] = "mengonsumsi",
    ["mempengaruhi"] = "memengaruhi",
    ["menterjemahkan"] = "menerjemahkan",
    ["dibawah"] = "di bawah",
    ["diatas"] = "di atas",
    ["disini"] = "di sini",
    ["disitu"] = "di situ",
    ["disana"] = "di sana",
    ["diluar"] = "di luar",
    ["didalam"] = "di dalam",
    ["didepan"] = "di depan",
    ["dibelakang"] = "di belakang",
    ["diantara"] = "di antara",
    ["dirumah"] = "di rumah",
    ["dikantor"] = "di kantor",
    ["disekolah"] = "di sekolah",
    ["dimana"] = "di mana",
    ["kemana"] = "ke mana",
    ["kesini"] = "ke sini",
    ["kesitu"] = "ke situ",
    ["kesana"] = "ke sana",
    ["kedalam"] = "ke dalam",
    ["kebawah"] = "ke bawah",
    ["keatas"] = "ke atas",
    ["kerumah"] = "ke rumah",
    ["kekantor"] = "ke kantor",
    ["kesekolah"] = "ke sekolah",
    ["apapun"] = "apa pun",
    ["siapapun"] = "siapa pun",
    ["kapanpun"] = "kapan pun",
    ["manapun"] = "mana pun",
    ["dimanapun"] = "di mana pun"
}

khusus.spellingSuffixes = { "nya", "ku", "mu", "lah", "kah" }

function khusus.matchCase(source, replacement)
    if #source > 1 and source == source:upper() then
        return replacement:upper()
    end
    if source:match("^%u") then
        return replacement:sub(1, 1):upper() .. replacement:sub(2)
    end
    return replacement
end

function khusus.correctWord(word)
    local lower = word:lower()
    local fixed = khusus.standardSpelling[lower]
    local tail = ""
    if fixed == nil then
        for _, suffix in ipairs(khusus.spellingSuffixes) do
            if #lower > #suffix + 2 and lower:sub(-#suffix) == suffix then
                fixed = khusus.standardSpelling[lower:sub(1, -#suffix - 1)]
                if fixed ~= nil then
                    tail = word:sub(-#suffix)
                    break
                end
            end
        end
    end
    if fixed == nil then
        return word
    end
    return khusus.matchCase(word:sub(1, #word - #tail), fixed) .. tail
end

function khusus.joinReduplication(text)
    local result = text:gsub("()(%a%a%a+) (%a%a%a+[nN][yY][aA])%f[%A]", function(position, first, second)
        if second:lower() ~= first:lower() .. "nya" then
            return nil
        end
        if position > 1 and text:sub(position - 1, position - 1) == "-" then
            return nil
        end
        return first .. "-" .. second
    end)
    return result
end

function khusus.correctSpelling(text)
    if not logicIndonesian then
        return text
    end
    local result = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") then
            return token
        end
        local fixed = token:gsub("%f[%a]%a+%f[%A]", khusus.correctWord)
        return fixed
    end)
    return khusus.joinReduplication(result)
end

function khusus.urlEncode(text)
    if text == nil or text == "" then
        return ""
    end
    return Uri.encode(tostring(text))
end

function khusus.tryClient(txt, sl, tl, client)
    if khusus.offlineOnly() then
        return nil, khusus.offlineMessage()
    end
    local conn, reader
    local ok, resultVal, errVal = pcall(function()
        local url = "https://translate.googleapis.com/translate_a/single?client=" .. client .. "&sl=" .. sl .. "&tl=" .. tl .. "&dt=t&dj=1&q=" .. khusus.urlEncode(txt)
        conn = URL(url).openConnection()
        conn.setRequestMethod("GET")
        conn.setRequestProperty("User-Agent", khusus.userAgent)
        conn.setRequestProperty("Accept", "application/json")
        conn.setConnectTimeout(10000)
        conn.setReadTimeout(10000)
        local code = conn.getResponseCode()
        if code ~= 200 then
            return nil, "HTTP " .. tostring(code) .. T(" dari client ", " from client ") .. client
        end
        reader = BufferedReader(InputStreamReader(conn.getInputStream(), "UTF-8"))
        local sb = StringBuilder()
        local line = reader.readLine()
        while line ~= nil do
            sb.append(line)
            line = reader.readLine()
        end
        local raw = tostring(sb.toString())
        if not raw:match("^%s*{") then
            return nil, T("Respons client ", "Client response ") .. client .. T(" bukan JSON", " is not JSON")
        end
        local translation = ""
        local parsedOk, data = false, nil
        if khusus.json then
            parsedOk, data = pcall(khusus.json.decode, raw)
        end
        if parsedOk and type(data) == "table" and data.sentences then
            for _, sentence in ipairs(data.sentences) do
                if sentence.trans then
                    translation = translation .. tostring(sentence.trans)
                end
            end
        end
        if translation == "" then
            for segment in raw:gmatch('"trans"%s*:%s*"(.-)"') do
                segment = segment:gsub('\\"', '"'):gsub('\\n', '\n'):gsub('\\t', '\t'):gsub('\\\\', '\\')
                translation = translation .. segment
            end
        end
        if translation == "" then
            return nil, "Client " .. client .. T(" tidak mengembalikan hasil terjemahan", " returned no translation result")
        end
        local detected = nil
        if parsedOk and type(data) == "table" and data.src then
            detected = tostring(data.src)
        end
        if not detected then
            detected = raw:match('"src"%s*:%s*"([^"]+)"')
        end
        khusus.lastDetected = detected
        return translation, nil
    end)
    pcall(function() if reader then reader.close() end end)
    pcall(function() if conn then conn.disconnect() end end)
    if not ok then
        return nil, T("Error koneksi: ", "Connection error: ") .. tostring(resultVal)
    end
    return resultVal, errVal
end

function khusus.fetch(txt, sl, tl)
    math.randomseed(math.floor(os.time() + os.clock() * 1000))
    local order = khusus.clients
    if math.random(1, 2) == 2 then
        order = { khusus.clients[2], khusus.clients[1] }
    end
    local lastError = T("Tidak ada respons dari server terjemahan", "No response from the translation server")
    for _, client in ipairs(order) do
        local ok, result, err = pcall(khusus.tryClient, txt, sl, tl, client)
        if ok and result and result ~= "" then
            return result
        end
        if not ok then
            lastError = T("Error koneksi: ", "Connection error: ") .. tostring(result)
        elseif err then
            lastError = err
        end
    end
    return nil, lastError
end

function khusus.chunk(txt, maxLen)
    txt = tostring(txt or "")
    if #txt <= maxLen then
        return { txt }
    end
    local lines = {}
    local pos = 1
    while pos <= #txt do
        local nl = txt:find("\n", pos, true)
        if nl then
            lines[#lines + 1] = txt:sub(pos, nl)
            pos = nl + 1
        else
            lines[#lines + 1] = txt:sub(pos)
            pos = #txt + 1
        end
    end
    local units = {}
    for _, line in ipairs(lines) do
        if #line <= maxLen then
            units[#units + 1] = line
        else
            local sp = 1
            while sp <= #line do
                local _, e = line:find("[%.%!%?]+%s+", sp)
                local piece
                if e then
                    piece = line:sub(sp, e)
                    sp = e + 1
                else
                    piece = line:sub(sp)
                    sp = #line + 1
                end
                while #piece > maxLen do
                    local cut = maxLen
                    local lastSpace = piece:sub(1, cut):match(".*()%s")
                    if lastSpace and lastSpace > 1 then
                        cut = lastSpace
                    else
                        while cut > 1 do
                            local b = piece:byte(cut + 1)
                            if b and b >= 128 and b < 192 then
                                cut = cut - 1
                            else
                                break
                            end
                        end
                    end
                    units[#units + 1] = piece:sub(1, cut)
                    piece = piece:sub(cut + 1)
                end
                if piece ~= "" then
                    units[#units + 1] = piece
                end
            end
        end
    end
    local chunks = {}
    local current = ""
    for _, unit in ipairs(units) do
        if current ~= "" and #current + #unit > maxLen then
            chunks[#chunks + 1] = current
            current = unit
        else
            current = current .. unit
        end
    end
    if current ~= "" then
        chunks[#chunks + 1] = current
    end
    if #chunks == 0 then
        chunks[1] = txt
    end
    return chunks
end

function khusus.baseCode(code)
    code = tostring(code or ""):lower():match("^([^%-_]+)") or ""
    if code == "jw" then
        code = "jv"
    end
    return code
end

function khusus.httpGet(urlStr)
    if khusus.offlineOnly() then
        return -1, ""
    end
    local conn, reader
    local ok, status, body = pcall(function()
        conn = URL(urlStr).openConnection()
        conn.setRequestMethod("GET")
        conn.setRequestProperty("User-Agent", khusus.userAgent)
        conn.setConnectTimeout(10000)
        conn.setReadTimeout(15000)
        local code = tonumber(conn.getResponseCode()) or -1
        local stream = (code >= 200 and code < 300) and conn.getInputStream() or conn.getErrorStream()
        local text = ""
        if stream then
            reader = BufferedReader(InputStreamReader(stream, "UTF-8"))
            local sb = StringBuilder()
            local line = reader.readLine()
            while line ~= nil do
                sb.append(line)
                line = reader.readLine()
            end
            text = tostring(sb.toString())
        end
        return code, text
    end)
    pcall(function() if reader then reader.close() end end)
    pcall(function() if conn then conn.disconnect() end end)
    if not ok then
        return -1, ""
    end
    return status, body
end

function khusus.myMemory(txt, sl, tl)
    local found = nil
    pcall(function()
        local function code(x)
            x = tostring(x or "")
            if x == "jw" then
                return "jv"
            end
            return x
        end
        local src = (sl == nil or sl == "" or sl == "auto") and "autodetect" or code(sl)
        local pair = src .. "|" .. code(tl)
        local parts = khusus.chunk(txt, 450)
        local joined = {}
        for i, part in ipairs(parts) do
            local url = "https://api.mymemory.translated.net/get?q=" .. khusus.urlEncode(part) .. "&langpair=" .. khusus.urlEncode(pair)
            local status, body = khusus.httpGet(url)
            if status ~= 200 or body == "" then
                return
            end
            if not khusus.json then
                return
            end
            local okJ, data = pcall(khusus.json.decode, body)
            if not okJ or type(data) ~= "table" then
                return
            end
            local rd = data.responseData
            local translated = (type(rd) == "table") and rd.translatedText or nil
            if type(translated) ~= "string" or translated == "" then
                return
            end
            if tonumber(data.responseStatus) ~= 200 then
                return
            end
            local upper = translated:upper()
            if upper:find("^MYMEMORY WARNING") or upper:find("^PLEASE SELECT") or upper:find("^INVALID") then
                return
            end
            translated = translated:gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
            local clean = (translated:gsub("%s+$", ""))
            if i < #parts then
                local tail = part:match("%s*$") or ""
                clean = clean .. (tail ~= "" and tail or " ")
            end
            joined[#joined + 1] = clean
        end
        local all = table.concat(joined, "")
        if all ~= "" then
            found = all
        end
    end)
    return found
end

function khusus.fixMixed(text, targetLang)
    text = tostring(text or "")
    local previousDetected = khusus.lastDetected
    local finalText = text
    pcall(function()
        if text:find("[\r\n]") then
            return
        end
        local words = {}
        for word in text:gmatch("%S+") do
            words[#words + 1] = word
        end
        if #words < 2 or #words > 90 then
            return
        end
        local size = 3
        if #words > 45 then
            size = 5
        end
        local target = khusus.baseCode(targetLang)
        local result = {}
        local changed = false
        local failures = 0
        local i = 1
        while i <= #words do
            local group = {}
            for j = i, math.min(i + size - 1, #words) do
                group[#group + 1] = words[j]
            end
            local piece = table.concat(group, " ")
            local use = piece
            if failures < 3 and piece:find("[%w\128-\255]") then
                khusus.lastDetected = nil
                local okF, res = pcall(khusus.fetch, piece, "auto", targetLang)
                if okF and res and res ~= "" then
                    failures = 0
                    local detected = khusus.baseCode(khusus.lastDetected)
                    local trimmed = khusus.trim(res)
                    if detected ~= "" and detected ~= target and trimmed ~= "" and trimmed:lower() ~= piece:lower() then
                        use = trimmed
                        changed = true
                    end
                else
                    failures = failures + 1
                end
            end
            result[#result + 1] = use
            i = i + size
        end
        if changed then
            finalText = table.concat(result, " ")
        end
    end)
    khusus.lastDetected = previousDetected
    return finalText
end

function khusus.translate(txt, sl, tl, callback, raw)
    if not txt or txt == "" then
        callback(txt)
        return
    end
    if khusus.offlineOnly() then
        service.speak(khusus.offlineMessage())
        callback(txt)
        return
    end
    local generation = khusus.generation
    Thread(function()
        local ok, result, err = pcall(function()
            local parts = khusus.chunk(txt, 1000)
            local function fetchAll(source)
                if #parts == 1 then
                    local single, singleErr = khusus.fetch(parts[1], source, tl)
                    if single and single ~= "" then
                        return single, nil
                    end
                    return nil, singleErr or T("gagal terjemahkan", "translation failed")
                end
                local joined = {}
                for i, part in ipairs(parts) do
                    local piece, pieceErr = khusus.fetch(part, source, tl)
                    if not piece or piece == "" then
                        return nil, pieceErr or T("gagal terjemahkan", "translation failed")
                    end
                    local clean = (piece:gsub("%s+$", ""))
                    if i < #parts then
                        local tail = part:match("%s*$") or ""
                        clean = clean .. (tail ~= "" and tail or " ")
                    end
                    joined[#joined + 1] = clean
                end
                return table.concat(joined, ""), nil
            end
            local r, e = fetchAll(sl)
            if (not r) and sl == "auto" then
                local r2 = fetchAll("id")
                if r2 then
                    r, e = r2, nil
                end
            end
            if not r then
                local okM, fromMemory = pcall(khusus.myMemory, txt, sl, tl)
                if okM and fromMemory and fromMemory ~= "" then
                    r, e = fromMemory, nil
                end
            end
            if r and sl == "auto" then
                local okP, fixed = pcall(khusus.fixMixed, r, tl)
                if okP and fixed and fixed ~= "" then
                    r = fixed
                end
            end
            return r, e
        end)
        khusus.handler.post(function()
            if generation ~= khusus.generation then
                return
            end
            if ok and result and result ~= "" then
                result = khusus.keepOkAfterTranslate(txt, result, tl)
                if raw then
                    callback(result)
                else
                    callback(khusus.addPunctuation(khusus.capitalizeFirst(result)))
                end
            else
                local reason = (not ok) and tostring(result) or tostring(err or T("gagal terjemahkan", "translation failed"))
                service.speak(T("Terjemahan gagal: ", "Translation failed: ") .. reason)
                callback(txt)
            end
        end)
    end).start()
end

function khusus.speakAfterMicrophone(message)
    khusus.autoTypeHold = System.currentTimeMillis() + 1200 + #tostring(message) * 90
    local scheduled = pcall(function()
        khusus.handler.postDelayed(function()
            service.speak(message)
        end, 500)
    end)
    if not scheduled then
        service.speak(message)
    end
end

function khusus.copyToClipboard(text)
    local copied = pcall(function()
        local manager = this.getSystemService(Context.CLIPBOARD_SERVICE)
        manager.setPrimaryClip(ClipData.newPlainText("Bjr", text))
    end)
    return copied
end

khusus.languageTriggers = languageTriggers

khusus.tabelFileName = "tabel_gaya_bicara.lua"
khusus.tabelGroups = nil
khusus.tabelState = {}
khusus.tabelRetryAt = 0
khusus.tabelWarned = false

khusus.tabelKeys = {
    palembangWords = "palembang", palembangKeep = "palembang",
    stylePhrases = "singkatan", styleWords = "singkatan",
    jakselNegations = "jaksel", jakselNegationEndings = "jaksel", jakselIndonesianPhrases = "jaksel", jakselEnglishPhrases = "jaksel", jakselIndonesianWords = "jaksel", jakselEnglishWords = "jaksel", jakselPhrases = "jaksel", jakselWords = "jaksel",
    gagapFillers = "gagap", gagapForms = "gagap",
    cadelThWords = "cadel",
    betawiWords = "betawi", betawiPhrases = "betawi", betawiOnceAfter = "betawi", betawiOnceBefore = "betawi",
    tionghoaWords = "tionghoa", tionghoaPhrases = "tionghoa",
    islamiWords = "islami", islamiPhrases = "islami",
    gaulFillers = "gaul", gaulWords = "gaul", gaulPhrases = "gaul",
    lucuFillers = "lucu", lucuEndings = "lucu", lucuWords = "lucu", lucuPhrases = "lucu",
    santriFillers = "santri", santriEndings = "santri", santriWords = "santri", santriPhrases = "santri",
    robotWords = "robot",
    lebayWords = "lebay",
    ngapakWords = "ngapak", ngapakPhrases = "ngapak", ngapakIntensifyBlockers = "ngapak", ngapakKeepEndings = "ngapak", ngapakKeepAfter = "ngapak", ngapakKeepBefore = "ngapak",
    alayWords = "alay"
}

function khusus.tabelRead(path)
    local file = File(path)
    if not file.isFile() then
        return nil
    end
    local reader = BufferedReader(InputStreamReader(FileInputStream(file), "UTF-8"))
    local collected = {}
    while true do
        local line = reader.readLine()
        if line == nil then
            break
        end
        collected[#collected + 1] = tostring(line)
    end
    reader.close()
    local source = table.concat(collected, "\n")
    source = source:gsub("^\239\187\191", ""):gsub("^\239\187\191", "")
    return source
end

function khusus.tabelOpen()
    if khusus.tabelGroups ~= nil then
        return khusus.tabelGroups
    end
    local now = System.currentTimeMillis()
    if now < khusus.tabelRetryAt then
        return nil
    end
    local compile = loadstring or load
    local found = nil
    local listed, directories = pcall(khusus.introDirectories)
    if listed and type(directories) == "table" then
        for _, directory in ipairs(directories) do
            local read, source = pcall(khusus.tabelRead, directory .. "/" .. khusus.tabelFileName)
            if read and type(source) == "string" and source ~= "" then
                local compiled, chunk = pcall(compile, source, "=" .. khusus.tabelFileName)
                if compiled and type(chunk) == "function" then
                    local ran, groups = pcall(chunk)
                    if ran and type(groups) == "table" then
                        found = groups
                        break
                    end
                end
            end
        end
    end
    if found == nil then
        khusus.tabelRetryAt = now + 3000
        return nil
    end
    khusus.tabelGroups = found
    return found
end

khusus.tabelFiles = {}

function khusus.tabelEval(name)
    local cached = khusus.tabelFiles[name]
    if cached ~= nil then
        return cached
    end
    local compile = loadstring or load
    local listed, directories = pcall(khusus.introDirectories)
    if not listed or type(directories) ~= "table" then
        return nil
    end
    for _, directory in ipairs(directories) do
        local read, source = pcall(khusus.tabelRead, directory .. "/" .. name)
        if read and type(source) == "string" and source ~= "" then
            local compiled, chunk = pcall(compile, source, "=" .. name)
            if compiled and type(chunk) == "function" then
                local ran, value = pcall(chunk)
                if ran and type(value) == "table" then
                    khusus.tabelFiles[name] = value
                    return value
                end
            end
        end
    end
    return nil
end

function khusus.tabelWarn()
    if khusus.tabelWarned then
        return
    end
    khusus.tabelWarned = true
    pcall(function()
        service.speak(T("File tabel gaya bicara tidak ditemukan atau rusak. Letakkan file tabel_gaya_bicara.lua di folder yang sama dengan main.lua.", "The speaking style table file was not found or is damaged. Put the file tabel_gaya_bicara.lua in the same folder as main.lua."))
    end)
end

function khusus.tabelRun(group)
    local state = khusus.tabelState[group]
    if state == true then
        return true
    end
    if state == "busy" then
        return false
    end
    local groups = khusus.tabelOpen()
    local loader = nil
    if groups ~= nil then
        loader = groups[group]
    end
    if type(loader) ~= "function" then
        khusus.tabelWarn()
        return false
    end
    khusus.tabelState[group] = "busy"
    local ran = pcall(loader, khusus, pickLogic, logicIndonesian, triggerPrefix, chooseSet, T)
    if ran then
        khusus.tabelState[group] = true
        return true
    end
    khusus.tabelState[group] = nil
    khusus.tabelWarn()
    return false
end

setmetatable(khusus, {
    __index = function(owner, key)
        local group = khusus.tabelKeys[key]
        if group == nil then
            return nil
        end
        khusus.tabelRun(group)
        return rawget(owner, key)
    end
})

guideSections.load = function()
    local compile = loadstring or load
    local listed, directories = pcall(khusus.introDirectories)
    if not listed or type(directories) ~= "table" then
        return false
    end
    for _, directory in ipairs(directories) do
        local read, source = pcall(khusus.tabelRead, directory .. "/tabel_petunjuk.lua")
        if read and type(source) == "string" and source ~= "" then
            local compiled, chunk = pcall(compile, source, "=tabel_petunjuk.lua")
            if compiled and type(chunk) == "function" then
                local ran, builder = pcall(chunk)
                if ran and type(builder) == "function" then
                    local built, sections = pcall(builder, T)
                    if built and type(sections) == "table" and #sections > 0 then
                        for index, section in ipairs(sections) do
                            guideSections[index] = section
                        end
                        guideSections.loaded = true
                        return true
                    end
                end
            end
        end
    end
    return false
end


function khusus.palembang(text)
    local converted = text:gsub("%a+", function(word)
        if word:match("^%u+$") then
            return word
        end
        local lower = word:lower()
        local replaced = khusus.palembangWords[lower]
        if replaced == nil and #lower >= 3 and lower:sub(-1) == "a" and khusus.palembangKeep[lower] == nil then
            replaced = lower:sub(1, -2) .. "o"
        end
        if replaced == nil then
            return word
        end
        if word:sub(1, 1):match("%u") ~= nil then
            replaced = replaced:sub(1, 1):upper() .. replaced:sub(2)
        end
        return replaced
    end)
    return converted
end

function khusus.extractLanguageTrigger(text)
    local lowered = text:lower()
    for _, spec in ipairs(khusus.languageTriggers) do
        local _, finish = lowered:find("^%s*" .. triggerPrefix .. "%s+" .. spec[1])
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, spec
            end
        end
    end
    return text, nil
end

khusus.styleTrigger = pickLogic("singkatan%s+umum", "common%s+abbreviations")

function khusus.replacePhrase(text, pattern, short)
    local lowered = text:lower()
    local pieces = {}
    local position = 1
    while true do
        local first, last = lowered:find(pattern, position)
        if first == nil then
            break
        end
        local before = ""
        if first > 1 then
            before = lowered:sub(first - 1, first - 1)
        end
        local after = lowered:sub(last + 1, last + 1)
        if before:match("%w") == nil and after:match("%w") == nil then
            pieces[#pieces + 1] = text:sub(position, first - 1)
            pieces[#pieces + 1] = khusus.matchCase(text:sub(first, last), short)
        else
            pieces[#pieces + 1] = text:sub(position, last)
        end
        position = last + 1
    end
    pieces[#pieces + 1] = text:sub(position)
    return table.concat(pieces)
end

function khusus.abbreviate(text)
    for _, entry in ipairs(khusus.stylePhrases) do
        text = khusus.replacePhrase(text, entry[1], entry[2])
    end
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            local short = khusus.styleWords[word:lower()]
            if short == nil then
                return word
            end
            return khusus.matchCase(word, short)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractStyleTrigger(text)
    local lowered = text:lower()
    local _, finish = lowered:find("^%s*" .. khusus.styleTrigger)
    if finish ~= nil then
        local nextChar = text:sub(finish + 1, finish + 1)
        if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
            local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
            return remainder, true
        end
    end
    return text, false
end

khusus.jakselTriggers = pickLogic({
    "singkatan%s+jak%s*sel",
    "singkatan%s+jakarta%s+selatan"
}, {
    "jaksel%s+abbreviations",
    "jaksel%s+abbreviation"
})


function khusus.appendEntries(target, source)
    for _, entry in ipairs(source) do
        target[#target + 1] = entry
    end
end


function khusus.abbreviateJaksel(text)
    for _, entry in ipairs(khusus.jakselPhrases) do
        text = khusus.replacePhrase(text, entry[1], entry[2])
    end
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            local lowered = word:lower()
            local short = khusus.jakselWords[lowered]
            if short == nil then
                short = khusus.styleWords[lowered]
            end
            if short == nil then
                return word
            end
            return khusus.matchCase(word, short)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractJakselTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.jakselTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.gagapTriggers = pickLogic({
    "gagap",
    "gagab",
    "gagak"
}, {
    "stutter%s+style",
    "stuttering%s+style",
    "stutter%s+speech"
})


function khusus.stutter(text)
    local index = 0
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") or token:find("%a%-%a") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            index = index + 1
            local lowered = word:lower()
            if #lowered < 2 or word:sub(2):find("%u") or (index + #lowered) % 3 == 0 then
                return word
            end
            local capitalized = word:find("^%u") ~= nil
            local letter = lowered:sub(1, 1)
            local syllable = lowered:match("^[^aeiou']*[aeiou]") or letter
            if #syllable >= #lowered then
                syllable = letter
            end
            local form = khusus.gagapForms[(index + #lowered) % #khusus.gagapForms + 1]
            local result = form(letter, syllable, lowered)
            if capitalized then
                result = result:sub(1, 1):upper() .. result:sub(2)
            end
            if index > 1 and index % 6 == 0 then
                result = khusus.gagapFillers[index % #khusus.gagapFillers + 1] .. ", " .. result
            end
            return result
        end)
        return fixed
    end)
    return converted
end

function khusus.extractGagapTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.gagapTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.cadelTriggers = pickLogic({
    "cadel",
    "kadel",
    "cadal"
}, {
    "lisp%s+style",
    "lisping%s+style",
    "lisp%s+speech"
})


khusus.cadelWord = pickLogic(function(word)
    local converted = word:gsub("[Ss][Yy]", function(pair)
        if pair:sub(1, 1) == "S" then
            return "C"
        end
        return "c"
    end)
    converted = converted:gsub("[SsRr]", { s = "c", S = "C", r = "l", R = "L" })
    return converted
end, function(word)
    local lowered = word:lower()
    local converted = word
    if lowered:sub(1, 2) == "th" then
        local replacement = "f"
        if khusus.cadelThWords[lowered] then
            replacement = "d"
        end
        if word:sub(1, 1) == "T" then
            replacement = replacement:upper()
        end
        converted = replacement .. word:sub(3)
    end
    converted = converted:gsub("[Tt][Hh]", function(pair)
        if pair:sub(1, 1) == "T" then
            return "F"
        end
        return "f"
    end)
    converted = converted:gsub("[Rr]", { r = "w", R = "W" })
    converted = converted:gsub("([Ll]+)([AEIOUYaeiouy])", function(run, vowel)
        local softened = run:gsub("[Ll]", { l = "w", L = "W" })
        return softened .. vowel
    end)
    return converted
end)

function khusus.cadel(text)
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            if #word > 1 and word:sub(2):find("%u") then
                return word
            end
            return khusus.cadelWord(word)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractCadelTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.cadelTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.betawiTriggers = pickLogic({
    triggerPrefix .. "%s+betawi",
    triggerPrefix .. "%s+betawe",
    triggerPrefix .. "%s+bitawi"
}, {})

function khusus.betawiNeighbors(source, startPos, endPos)
    local previous = source:sub(1, startPos - 1):match("(%a+)[^%a]*$")
    local following = source:sub(endPos):match("^[^%a]*(%a+)")
    return (previous or ""):lower(), (following or ""):lower()
end

function khusus.betawiWord(word, previous, following)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local lowered = word:lower()
    if lowered == "sekali" and (khusus.betawiOnceAfter[following] or khusus.betawiOnceBefore[previous]) then
        return word
    end
    local replacement = khusus.betawiWords[lowered]
    if replacement == nil and #lowered > 5 and lowered:sub(-3) == "nya" then
        local base = lowered:sub(1, -4)
        if base ~= "sekali" then
            replacement = (khusus.betawiWords[base] or base) .. "nye"
        end
    end
    if replacement == nil then
        return word
    end
    return khusus.matchCase(word, replacement)
end

function khusus.betawi(text)
    for _, entry in ipairs(khusus.betawiPhrases) do
        text = khusus.replacePhrase(text, entry[1], entry[2])
    end
    local source = text
    local converted = source:gsub("()(%S+)()", function(startPos, token, endPos)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") then
            return token
        end
        local previous, following = khusus.betawiNeighbors(source, startPos, endPos)
        if token:find("%a%-%a") then
            previous = "sekali"
            following = "sekali"
        end
        local fixed = token:gsub("[%a']+", function(word)
            return khusus.betawiWord(word, previous, following)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractBetawiTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.betawiTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.tionghoaTriggers = pickLogic({
    "tionghoa",
    "tiong%s*hoa",
    "tionghua"
}, {})

function khusus.tionghoaWord(word)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local converted = word
    local replacement = khusus.tionghoaWords[word:lower()]
    if replacement ~= nil then
        converted = khusus.matchCase(word, replacement)
    end
    return (converted:gsub("[Rr]", { r = "l", R = "L" }))
end

function khusus.tionghoa(text)
    for _, entry in ipairs(khusus.tionghoaPhrases) do
        text = khusus.replacePhrase(text, entry[1], entry[2])
    end
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            return khusus.tionghoaWord(word)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractTionghoaTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.tionghoaTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.islamiTriggers = pickLogic({
    "islami",
    "islamy",
    "islam"
}, {})

function khusus.islamiWord(word)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local replacement = khusus.islamiWords[word:lower()]
    if replacement == nil then
        return word
    end
    return khusus.matchCase(word, replacement)
end

function khusus.islami(text)
    for _, entry in ipairs(khusus.islamiPhrases) do
        text = khusus.replacePhrase(text, entry[1], entry[2])
    end
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") or token:find("%a%-%a") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            return khusus.islamiWord(word)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractIslamiTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.islamiTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.buntetTriggers = pickLogic({
    "buntet",
    "buntut",
    "buntek"
}, {})

function khusus.buntetWord(word)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local converted = word:gsub("[Nn][YyGg]", function(pair)
        local first = pair:sub(1, 1)
        local second = pair:sub(2, 2)
        if second:lower() == "g" then
            if first == "N" then
                return "G"
            end
            return "g"
        end
        if first == "N" then
            return "D" .. second
        end
        return "d" .. second
    end)
    converted = converted:gsub("[MmNn]", { m = "b", M = "B", n = "d", N = "D" })
    return converted
end

function khusus.buntet(text)
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            return khusus.buntetWord(word)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractBuntetTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.buntetTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.gaulTriggers = pickLogic({
    "gaul",
    "kaul",
    "gaol"
}, {})

function khusus.gaulWord(word)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local replacement = khusus.gaulWords[word:lower()]
    if replacement == nil then
        return word
    end
    return khusus.matchCase(word, replacement)
end

function khusus.gaul(text)
    local count = 0
    local converted = text:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") or token:find("%a%-%a") then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            count = count + 1
            local result = khusus.gaulWord(word)
            if count > 1 and count % 7 == 0 then
                local choice = math.floor(count / 7) % #khusus.gaulFillers + 1
                result = khusus.gaulFillers[choice] .. " " .. result
            end
            return result
        end)
        return fixed
    end)
    for _, entry in ipairs(khusus.gaulPhrases) do
        converted = khusus.replacePhrase(converted, entry[1], entry[2])
    end
    return converted
end

function khusus.extractGaulTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.gaulTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.lucuTriggers = pickLogic({
    "lucu",
    "lucuh",
    "lucuk"
}, {})

function khusus.lucuWord(word)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local replacement = khusus.lucuWords[word:lower()]
    if replacement == nil then
        return word
    end
    return khusus.matchCase(word, replacement)
end

function khusus.lucu(text)
    local converted = text
    for _, entry in ipairs(khusus.lucuPhrases) do
        converted = khusus.replacePhrase(converted, entry[1], entry[2])
    end
    local count = 0
    converted = converted:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") or token:find("%a%-%a") then
            return token
        end
        local fixed = token:gsub("()([%a']+)", function(position, word)
            count = count + 1
            local result = khusus.lucuWord(word)
            if count > 1 and count % 5 == 0 and token:sub(position - 1, position - 1) ~= "\1" then
                local choice = math.floor(count / 5) % #khusus.lucuFillers + 1
                result = khusus.lucuFillers[choice] .. ", " .. result
            end
            return result
        end)
        return fixed
    end)
    converted = converted:gsub("\1", " ")
    converted = converted:gsub("%s+$", "")
    if converted ~= "" then
        local choice = count % #khusus.lucuEndings + 1
        converted = converted .. " " .. khusus.lucuEndings[choice]
    end
    return converted
end

function khusus.extractLucuTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.lucuTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.santriTriggers = pickLogic({
    "santri",
    "santry",
    "santre"
}, {})

function khusus.santriWord(word)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local replacement = khusus.santriWords[word:lower()]
    if replacement == nil then
        return word
    end
    return khusus.matchCase(word, replacement)
end

function khusus.santri(text)
    local converted = text
    for _, entry in ipairs(khusus.santriPhrases) do
        converted = khusus.replacePhrase(converted, entry[1], entry[2])
    end
    local count = 0
    converted = converted:gsub("%S+", function(token)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") or token:find("%a%-%a") then
            return token
        end
        local fixed = token:gsub("()([%a']+)", function(position, word)
            count = count + 1
            local result = khusus.santriWord(word)
            if count > 1 and count % 6 == 0 and token:sub(position - 1, position - 1) ~= "\1" then
                local choice = math.floor(count / 6) % #khusus.santriFillers + 1
                result = khusus.santriFillers[choice] .. ", " .. result
            end
            return result
        end)
        return fixed
    end)
    converted = converted:gsub("\1", " ")
    converted = converted:gsub("%s+$", "")
    if converted ~= "" then
        local choice = count % #khusus.santriEndings + 1
        converted = converted .. " " .. khusus.santriEndings[choice]
    end
    return converted
end

function khusus.extractSantriTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.santriTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.robotTriggers = pickLogic({
    "robot",
    "robod",
    "ropot"
}, {})

function khusus.protectedToken(token)
    return token:find("://", 1, true) ~= nil
        or token:find("@", 1, true) ~= nil
        or token:find("/", 1, true) ~= nil
        or token:find("%a%.%a") ~= nil
        or token:lower():find("^www%.") ~= nil
        or token:find("%d") ~= nil
        or token:find("%a%-%a") ~= nil
end

function khusus.robot(text)
    local parts = {}
    for token in text:gmatch("%S+") do
        if khusus.protectedToken(token) then
            local kept = token:gsub("[%.,;:!%?]+$", "")
            if kept ~= "" then
                parts[#parts + 1] = kept
            end
        else
            for word in token:gmatch("[%a']+") do
                if word:find("%a") then
                    local lowered = word:lower()
                    parts[#parts + 1] = (khusus.robotWords[lowered] or lowered):upper()
                end
            end
        end
    end
    if #parts == 0 then
        return ""
    end
    return table.concat(parts, ". ") .. "."
end

function khusus.extractRobotTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.robotTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.lebayTriggers = pickLogic({
    "lebay",
    "lebai",
    "lebey"
}, {})

function khusus.lebayStretch(word)
    local lowered = word:lower()
    local position = nil
    for index = #lowered, 1, -1 do
        if lowered:sub(index, index):find("[aiueo]") then
            position = index
            break
        end
    end
    if position == nil then
        return word
    end
    local run = 1
    while position - run >= 1 and lowered:sub(position - run, position - run) == lowered:sub(position, position) do
        run = run + 1
    end
    local letter = word:sub(position, position)
    local extra = letter:lower():rep(math.max(1, 3 - run))
    if #word > 1 and word == word:upper() then
        extra = letter:rep(math.max(1, 3 - run))
    end
    return word:sub(1, position) .. extra .. word:sub(position + 1)
end

function khusus.lebayWord(word)
    local replacement = khusus.lebayWords[word:lower()]
    if replacement == nil then
        return khusus.lebayStretch(word)
    end
    if #word > 1 and word == word:upper() then
        return replacement:upper()
    end
    if word:sub(1, 1) ~= word:sub(1, 1):lower() then
        return replacement:sub(1, 1):upper() .. replacement:sub(2)
    end
    return replacement
end

function khusus.lebay(text)
    local converted = text:gsub("%S+", function(token)
        if khusus.protectedToken(token) then
            return token
        end
        local fixed = token:gsub("[%a']+", khusus.lebayWord)
        return fixed
    end)
    return converted
end

function khusus.extractLebayTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.lebayTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.ngapakTriggers = pickLogic({
    triggerPrefix .. "%s+ngapak%s+banyumasan",
    triggerPrefix .. "%s+ngapak%s+banyumas",
    triggerPrefix .. "%s+ngapak",
    triggerPrefix .. "%s+banyumasan",
    triggerPrefix .. "%s+banyumas",
    "ngapak%s+banyumasan",
    "ngapak%s+banyumas",
    "ngapak",
    "banyumasan",
    "banyumas"
}, {})

function khusus.ngapakIntensify(text)
    local lowered = text:lower()
    local pieces = {}
    local position = 1
    while true do
        local first, last, adjective = lowered:find("sangat%s+([%a']+)", position)
        if first == nil then
            break
        end
        local before = ""
        if first > 1 then
            before = lowered:sub(first - 1, first - 1)
        end
        if before:match("%w") == nil and khusus.ngapakIntensifyBlockers[adjective] == nil then
            local original = text:sub(last - #adjective + 1, last)
            if text:sub(first, first):match("%u") ~= nil then
                original = original:sub(1, 1):upper() .. original:sub(2)
            end
            pieces[#pieces + 1] = text:sub(position, first - 1)
            pieces[#pieces + 1] = original .. " temen"
        else
            pieces[#pieces + 1] = text:sub(position, last)
        end
        position = last + 1
    end
    pieces[#pieces + 1] = text:sub(position)
    return table.concat(pieces)
end

function khusus.ngapakWord(word, previous, following)
    if #word > 1 and word == word:upper() then
        return word
    end
    if #word > 1 and word:sub(2):find("%u") then
        return word
    end
    local lowered = word:lower()
    local keepAfter = khusus.ngapakKeepAfter[lowered]
    if keepAfter ~= nil and keepAfter[following] then
        return word
    end
    local keepBefore = khusus.ngapakKeepBefore[lowered]
    if keepBefore ~= nil and keepBefore[previous] then
        return word
    end
    if lowered == "sekali" then
        if khusus.betawiOnceAfter[following] or khusus.betawiOnceBefore[previous] then
            return khusus.matchCase(word, "sepisan")
        end
        return khusus.matchCase(word, "temen")
    end
    local replacement = khusus.ngapakWords[lowered]
    if replacement == nil and #lowered > 5 and lowered:sub(-3) == "nya" then
        local allowed = true
        for _, ending in ipairs(khusus.ngapakKeepEndings) do
            if lowered:sub(-#ending) == ending then
                allowed = false
                break
            end
        end
        local base = lowered:sub(1, -4)
        local stem = khusus.ngapakWords[base]
        if allowed and (stem ~= nil or #base >= 4) then
            stem = stem or base
            if stem:sub(-1):match("[aiueo]") ~= nil then
                replacement = stem .. "ne"
            else
                replacement = stem .. "e"
            end
        end
    end
    if replacement == nil and #lowered > 4 then
        local tail = lowered:sub(-2)
        if tail == "ku" or tail == "mu" then
            local base = lowered:sub(1, -3)
            local stem = khusus.ngapakWords[base]
            if stem ~= nil and #base >= 3 and stem:find(" ", 1, true) == nil then
                replacement = stem .. tail
            end
        end
    end
    if replacement == nil then
        return word
    end
    return khusus.matchCase(word, replacement)
end

function khusus.ngapak(text)
    text = khusus.ngapakIntensify(text)
    for _, entry in ipairs(khusus.ngapakPhrases) do
        text = khusus.replacePhrase(text, entry[1], entry[2])
    end
    local source = text
    local converted = source:gsub("()(%S+)()", function(startPos, token, endPos)
        if token:find("://", 1, true) or token:find("@", 1, true) or token:find("/", 1, true) or token:find("%a%.%a") or token:lower():find("^www%.") or token:find("%d") then
            return token
        end
        local previous, following = khusus.betawiNeighbors(source, startPos, endPos)
        if token:find("%a%-%a") then
            for part in token:gmatch("[%a']+") do
                if #part < 3 then
                    return token
                end
            end
            previous = ""
            following = ""
        end
        local fixed = token:gsub("[%a']+", function(word)
            return khusus.ngapakWord(word, previous, following)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractNgapakTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.ngapakTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.alayTriggers = pickLogic({
    triggerPrefix .. "%s+alay",
    "alay",
    "alai"
}, {})

function khusus.alayMix(word, offset)
    local letters = 0
    local mixed = word:gsub("%a", function(letter)
        letters = letters + 1
        if (letters + offset) % 2 == 0 then
            return letter:upper()
        end
        return letter:lower()
    end)
    return mixed
end

function khusus.alay(text)
    local count = 0
    local converted = text:gsub("%S+", function(token)
        if khusus.protectedToken(token) then
            return token
        end
        local fixed = token:gsub("[%a']+", function(word)
            if #word > 1 and word == word:upper() then
                return word
            end
            if #word > 1 and word:sub(2):find("%u") then
                return word
            end
            count = count + 1
            local replacement = khusus.alayWords[word:lower()] or word
            return khusus.alayMix(replacement, count % 2)
        end)
        return fixed
    end)
    return converted
end

function khusus.extractAlayTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.alayTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.ejaanTriggers = pickLogic({
    "ejaan",
    "eja%s+an"
}, {
    "spelling",
    "spell%s+out"
})

khusus.ejaanLetterNames = {
    A = { "ay", "ei" },
    B = { "be", "bi", "bee" },
    C = { "ce", "se", "si", "see", "sea" },
    D = { "de", "di", "dee" },
    E = { "ee" },
    F = { "ef", "eff" },
    G = { "ge", "gi", "gee" },
    H = { "ha", "aitch", "eich" },
    I = { "ai", "eye" },
    J = { "je", "ji", "jay" },
    K = { "ka", "kay", "key" },
    L = { "el", "ell" },
    M = { "em" },
    N = { "en" },
    O = { "oh" },
    P = { "pe", "pi", "pea", "pee" },
    Q = { "ki", "kiu", "kyu", "cue", "queue" },
    R = { "er", "ar", "are" },
    S = { "es", "ess" },
    T = { "te", "ti", "tea", "tee" },
    U = { "yu", "you" },
    V = { "ve", "vi", "vee" },
    W = { "we" },
    X = { "eks", "ex", "ecs" },
    Y = { "ye", "wai", "why" },
    Z = { "zet", "zed", "zee", "zi" }
}

khusus.ejaanLetterMap = {}
for letter, names in pairs(khusus.ejaanLetterNames) do
    khusus.ejaanLetterMap[letter:lower()] = letter
    for _, name in ipairs(names) do
        khusus.ejaanLetterMap[name] = letter
    end
end

khusus.ejaanDigitNames = {
    nol = "0", nul = "0", kosong = "0", zero = "0",
    satu = "1", one = "1",
    dua = "2", two = "2",
    tiga = "3", three = "3",
    empat = "4", four = "4",
    lima = "5", five = "5",
    enam = "6", six = "6",
    tujuh = "7", seven = "7",
    delapan = "8", eight = "8",
    sembilan = "9", nine = "9"
}

khusus.ejaanSymbolNames = {
    titik = ".", dot = ".",
    strip = "-", minus = "-", dash = "-", hyphen = "-",
    underscore = "_", at = "@", slash = "/"
}

khusus.ejaanPairs = {
    double = { you = "W", u = "W" },
    dobel = { yu = "W", u = "W" },
    dabel = { yu = "W", u = "W" },
    garis = { bawah = "_", miring = "/" }
}

function khusus.ejaanTrim(token)
    local trimmed = token:gsub("^[%p%s]+", "")
    trimmed = trimmed:gsub("[%p%s]+$", "")
    return trimmed
end

function khusus.ejaanDotted(trimmed)
    if trimmed:find(".", 1, true) == nil then
        return nil
    end
    local letters = {}
    for segment in (trimmed .. "."):gmatch("([^.]*)%.") do
        if #segment ~= 1 or segment:match("%a") == nil then
            return nil
        end
        letters[#letters + 1] = segment:upper()
    end
    return letters
end

function khusus.ejaan(text)
    local tokens = {}
    for token in tostring(text):gmatch("%S+") do
        tokens[#tokens + 1] = token
    end
    local parts = {}
    local lastKind = nil
    local function push(value, kind)
        if value == "" then
            return
        end
        if lastKind == "mark" then
            parts[#parts + 1] = " "
        elseif kind ~= "symbol" and lastKind ~= nil and lastKind ~= "symbol" and (kind == "word" or lastKind == "word") then
            parts[#parts + 1] = " "
        end
        parts[#parts + 1] = value
        lastKind = kind
    end
    local function isUnitToken(position)
        local raw = tokens[position]
        if raw == nil then
            return false
        end
        local trimmedRaw = khusus.ejaanTrim(raw)
        local cleanRaw = trimmedRaw:lower()
        if cleanRaw == "" then
            return false
        end
        if khusus.ejaanDigitNames[cleanRaw] ~= nil or cleanRaw:match("^%d+$") ~= nil then
            return true
        end
        if khusus.ejaanLetterMap[cleanRaw] ~= nil then
            return true
        end
        return khusus.ejaanDotted(trimmedRaw) ~= nil
    end
    local index = 1
    while index <= #tokens do
        local token = tokens[index]
        local trimmed = khusus.ejaanTrim(token)
        local clean = trimmed:lower()
        if trimmed == "" then
            if #token == 1 and token:find("[%.%-_@/]") ~= nil then
                push(token, "symbol")
            elseif lastKind == "word" and token:match("^[,;:%?!%.]+$") ~= nil then
                parts[#parts + 1] = token
                lastKind = "mark"
            end
        elseif clean == "spasi" or clean == "space" then
            if #parts > 0 and parts[#parts] ~= " " then
                parts[#parts + 1] = " "
            end
            lastKind = "symbol"
        else
            local pairValue = nil
            local pairSet = khusus.ejaanPairs[clean]
            if pairSet ~= nil and tokens[index + 1] ~= nil then
                pairValue = pairSet[khusus.ejaanTrim(tokens[index + 1]):lower()]
            end
            local dotted = khusus.ejaanDotted(trimmed)
            if pairValue ~= nil then
                push(pairValue, pairValue:match("%a") ~= nil and "unit" or "symbol")
                index = index + 1
            elseif khusus.ejaanDigitNames[clean] ~= nil then
                push(khusus.ejaanDigitNames[clean], "unit")
            elseif khusus.ejaanSymbolNames[clean] ~= nil then
                push(khusus.ejaanSymbolNames[clean], "symbol")
            elseif khusus.ejaanLetterMap[clean] ~= nil and (#clean == 1 or isUnitToken(index - 1) or isUnitToken(index + 1)) then
                push(khusus.ejaanLetterMap[clean], "unit")
            elseif dotted ~= nil then
                for _, letter in ipairs(dotted) do
                    push(letter, "unit")
                end
            elseif clean:match("^%d+$") ~= nil then
                push(clean, "unit")
            else
                push(trimmed, "word")
                local marks = token:match("([,;:%?!%.]+)$")
                if marks ~= nil then
                    parts[#parts + 1] = marks
                    lastKind = "mark"
                end
            end
        end
        index = index + 1
    end
    return khusus.trim(table.concat(parts))
end

function khusus.extractEjaanTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.ejaanTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, true
            end
        end
    end
    return text, false
end

khusus.sandiTriggers = pickLogic({
    "kata%s+sandi",
    "sandi",
    "password"
}, {
    "password",
    "passcode"
})

khusus.sandiLowerWords = pickLogic({
    "huruf%s+kecil"
}, {
    "lowercase",
    "lower%s+case"
})

function khusus.extractSandiTrigger(text)
    local lowered = text:lower()
    for _, pattern in ipairs(khusus.sandiTriggers) do
        local _, finish = lowered:find("^%s*" .. pattern)
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                local smallLetters = false
                local remainderLowered = remainder:lower()
                for _, word in ipairs(khusus.sandiLowerWords) do
                    local _, wordEnd = remainderLowered:find("^" .. word)
                    if wordEnd ~= nil then
                        local after = remainder:sub(wordEnd + 1, wordEnd + 1)
                        if after == "" or after:match("[%s%p]") ~= nil then
                            smallLetters = true
                            remainder = remainder:sub(wordEnd + 1):gsub("^[%s,%.:;!%?%-]+", "")
                            break
                        end
                    end
                end
                return remainder, true, smallLetters
            end
        end
    end
    return text, false, false
end

khusus.moneyWords = {}
do
    local unitNames = { "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan" }
    for index, name in ipairs(unitNames) do
        khusus.moneyWords[name] = { { kind = "unit", value = index } }
    end
    khusus.moneyWords["nol"] = { { kind = "unit", value = 0 } }
    khusus.moneyWords["kosong"] = { { kind = "unit", value = 0 } }
    khusus.moneyWords["sepuluh"] = { { kind = "fixed", value = 10 } }
    khusus.moneyWords["sebelas"] = { { kind = "fixed", value = 11 } }
    khusus.moneyWords["belas"] = { { kind = "teen" } }
    khusus.moneyWords["puluh"] = { { kind = "ten" } }
    khusus.moneyWords["ratus"] = { { kind = "hundred" } }
    khusus.moneyWords["koma"] = { { kind = "comma" } }
    khusus.moneyWords["setengah"] = { { kind = "fraction", numerator = 1, denominator = 2 } }
    khusus.moneyWords["seperempat"] = { { kind = "fraction", numerator = 1, denominator = 4 } }
    khusus.moneyWords["seratus"] = { { kind = "unit", value = 1, implicit = true }, { kind = "hundred" } }
    local scales = { ribu = 1000, juta = 1000000, miliar = 1000000000, milyar = 1000000000, triliun = 1000000000000 }
    for name, value in pairs(scales) do
        khusus.moneyWords[name] = { { kind = "scale", value = value } }
        khusus.moneyWords["se" .. name] = { { kind = "unit", value = 1, implicit = true }, { kind = "scale", value = value } }
        khusus.moneyWords[name .. "an"] = { { kind = "scale", value = value, approx = true } }
        khusus.moneyWords["se" .. name .. "an"] = { { kind = "unit", value = 1, implicit = true }, { kind = "scale", value = value, approx = true } }
    end
end

khusus.moneyCues = {}
for word in ([[harga harganya seharga berharga bayar bayarnya membayar dibayar dibayarkan pembayaran biaya biayanya gaji gajinya gajian uang uangnya duit tarif tarifnya ongkos ongkir tagihan cicilan cicil modal bunga denda upah honor bonus tabungan saldo transfer beli membeli dibeli jual menjual dijual terjual murah mahal diskon potongan utang hutang pinjam pinjaman sewa nominal anggaran budget dana pajak komisi untung rugi laba omzet pendapatan penghasilan rp rupiah senilai sebesar nilai nilainya kisaran patokan tebusan hadiah donasi sumbangan iuran kas setoran belanja kembalian thr]]):gmatch("%S+") do
    khusus.moneyCues[word] = true
end

khusus.moneyBlockers = {}
for word in ([[orang buah biji ekor unit pcs lembar butir kali kilo kg gram meter km liter tahun bulan minggu hari jam menit detik persen kata halaman baris pengguna penonton pengikut follower followers subscriber siswa murid warga penduduk hektare jiwa kepala keluarga kendaraan mobil motor rumah pesan komentar suara dolar dollar usd euro yen ringgit yuan won pound sen]]):gmatch("%S+") do
    khusus.moneyBlockers[word] = true
end

function khusus.moneyDigits(core)
    if #core > 15 or core:find("^0%d") then
        return nil
    end
    if core:find("^%d+$") then
        return { { kind = "unit", value = tonumber(core), digits = true, raw = core } }
    end
    local first, rest = core:match("^(%d+)(.*)$")
    if first == nil or rest == "" then
        return nil
    end
    if #first <= 3 and first ~= "0" then
        local grouped = true
        local remaining = rest
        while remaining ~= "" do
            if remaining:find("^%.%d%d%d") then
                remaining = remaining:sub(5)
            else
                grouped = false
                break
            end
        end
        if grouped then
            local plain = core:gsub("%.", "")
            return { { kind = "unit", value = tonumber(plain), digits = true, raw = plain } }
        end
    end
    local whole, fraction = core:match("^(%d+)[%.,](%d+)$")
    if whole ~= nil then
        return { { kind = "decimal", whole = tonumber(whole), fraction = tonumber(fraction), length = #fraction } }
    end
    return nil
end

function khusus.moneyItems(core)
    if core == "" then
        return nil
    end
    local known = khusus.moneyWords[core:lower()]
    if known ~= nil then
        return known
    end
    if core:find("^%d") then
        return khusus.moneyDigits(core)
    end
    return nil
end

function khusus.moneyFractional(items, position)
    local count = #items
    local scaleItem = items[count]
    if scaleItem.kind ~= "scale" or position >= count then
        return nil
    end
    local left = {}
    for index = 1, position - 1 do
        local kind = items[index].kind
        if kind == "scale" or kind == "comma" or kind == "fraction" or kind == "decimal" then
            return nil
        end
        left[#left + 1] = items[index]
    end
    local whole = 0
    if #left > 0 then
        whole = khusus.moneyValue(left)
        if whole == nil or whole < 0 or whole > 999 then
            return nil
        end
    elseif items[position].kind == "comma" then
        return nil
    end
    local scale = scaleItem.value
    local part
    if items[position].kind == "fraction" then
        if position ~= count - 1 then
            return nil
        end
        part = items[position].numerator * scale / items[position].denominator
    else
        if position == count - 1 then
            return nil
        end
        local digits = {}
        for index = position + 1, count - 1 do
            local item = items[index]
            if item.kind ~= "unit" or item.implicit then
                return nil
            end
            local text
            if item.digits then
                text = item.raw
            elseif item.value <= 9 then
                text = string.format("%.0f", item.value)
            else
                return nil
            end
            if text == nil or not text:find("^%d+$") then
                return nil
            end
            digits[#digits + 1] = text
        end
        local fraction = table.concat(digits)
        if #fraction > 9 then
            return nil
        end
        part = tonumber(fraction) * scale / (10 ^ #fraction)
    end
    if part ~= math.floor(part) then
        return nil
    end
    local value = whole * scale + part
    if value > 999999999999999 then
        return nil
    end
    return value
end

function khusus.moneyValue(items)
    local count = #items
    if count == 0 then
        return nil
    end
    for index = 1, count do
        local kind = items[index].kind
        if kind == "comma" or kind == "fraction" then
            return khusus.moneyFractional(items, index)
        end
    end
    for index = 1, count do
        if items[index].kind == "decimal" then
            if count ~= 2 or index ~= 1 or items[2].kind ~= "scale" then
                return nil
            end
            local part = items[1].fraction * items[2].value / (10 ^ items[1].length)
            if part ~= math.floor(part) then
                return nil
            end
            local value = items[1].whole * items[2].value + part
            if value > 999999999999999 then
                return nil
            end
            return value
        end
    end
    if count == 1 and items[1].kind == "unit" and items[1].value == 0 then
        return 0
    end
    local total = 0
    local group = 0
    local pending = nil
    local pendingImplicit = false
    local stage = 0
    local lastScale = nil
    for index = 1, count do
        local item = items[index]
        local kind = item.kind
        if kind == "unit" then
            if pending ~= nil or item.value == 0 then
                return nil
            end
            pending = item.value
            pendingImplicit = item.implicit == true
        elseif kind == "fixed" then
            if pending ~= nil or stage > 1 then
                return nil
            end
            group = group + item.value
            stage = 3
        elseif kind == "hundred" or kind == "ten" or kind == "teen" then
            if pending == nil or pending < 1 or pending > 9 then
                return nil
            end
            if kind == "hundred" then
                if stage ~= 0 then
                    return nil
                end
                group = group + pending * 100
                stage = 1
            elseif kind == "ten" then
                if stage > 1 then
                    return nil
                end
                group = group + pending * 10
                stage = 2
            else
                if stage > 1 then
                    return nil
                end
                group = group + 10 + pending
                stage = 3
            end
            pending = nil
            pendingImplicit = false
        elseif kind == "scale" then
            if item.approx and index ~= count then
                return nil
            end
            if pending ~= nil then
                if stage > 2 or (pendingImplicit and group > 0) then
                    return nil
                end
                group = group + pending
                pending = nil
                pendingImplicit = false
            end
            if group <= 0 then
                return nil
            end
            if lastScale ~= nil and item.value >= lastScale then
                return nil
            end
            total = total + group * item.value
            group = 0
            stage = 0
            lastScale = item.value
        else
            return nil
        end
    end
    if pending ~= nil then
        if stage > 2 then
            return nil
        end
        group = group + pending
    end
    if group >= 100 and group % 50 == 0 and lastScale ~= nil and lastScale >= 1000000 then
        group = group * math.floor(lastScale / 1000)
    end
    total = total + group
    if total > 999999999999999 then
        return nil
    end
    return total
end

function khusus.moneyHasScale(items)
    for _, item in ipairs(items) do
        if item.kind == "scale" then
            return true
        end
    end
    return false
end

function khusus.moneyCue(tokens, start)
    for walk = start - 1, math.max(1, start - 4), -1 do
        if khusus.moneyCues[tokens[walk].core:lower()] then
            return true
        end
    end
    return false
end

function khusus.moneyPrefix(tokens, start)
    local before = tokens[start - 1]
    if before == nil or tokens[start].lead ~= "" then
        return nil
    end
    if before.core:lower() ~= "rp" or (before.trail ~= "" and before.trail ~= ".") then
        return nil
    end
    return before.first + #before.lead
end

function khusus.moneyFormat(value)
    local digits = string.format("%.0f", value)
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1."):reverse()
    if formatted:sub(1, 1) == "." then
        formatted = formatted:sub(2)
    end
    return "Rp" .. formatted
end

function khusus.moneyCrossed(tokens, index)
    local finish = index
    while tokens[finish + 1] ~= nil and tokens[finish + 1].items ~= nil and tokens[finish + 1].lead == "" and tokens[finish].trail:match("^[,%.]?$") ~= nil do
        finish = finish + 1
    end
    local strict = index
    while tokens[strict + 1] ~= nil and tokens[strict + 1].items ~= nil and tokens[strict].trail == "" and tokens[strict + 1].lead == "" do
        strict = strict + 1
    end
    local marker = tokens[finish + 1]
    local explicit = marker ~= nil and marker.lead == "" and marker.core:lower() == "rupiah" and tokens[finish].trail:match("^[,%.]?$") ~= nil
    if explicit then
        if strict == finish and tokens[finish].trail == "" then
            return nil
        end
    elseif finish == strict then
        return nil
    end
    local items = {}
    for walk = index, finish do
        for _, item in ipairs(tokens[walk].items) do
            items[#items + 1] = item
        end
    end
    local value = khusus.moneyValue(items)
    if value == nil then
        return nil
    end
    local prefix = khusus.moneyPrefix(tokens, index)
    if not explicit then
        if marker ~= nil and khusus.moneyBlockers[marker.core:lower()] == true then
            return nil
        end
        if not (khusus.moneyHasScale(items) and (prefix ~= nil or khusus.moneyCue(tokens, index))) then
            return nil
        end
    end
    local fromPosition = tokens[index].first + #tokens[index].lead
    if prefix ~= nil then
        fromPosition = prefix
    end
    if explicit then
        return { from = fromPosition, to = marker.last - #marker.trail, value = value }, finish + 2
    end
    return { from = fromPosition, to = tokens[finish].last - #tokens[finish].trail, value = value }, finish + 1
end

function khusus.rupiah(text)
    local tokens = {}
    local position = 1
    while true do
        local first, last = text:find("%S+", position)
        if first == nil then
            break
        end
        local token = text:sub(first, last)
        local lead, core, trail = token:match("^([^%w]*)(.-)([^%w]*)$")
        tokens[#tokens + 1] = { first = first, last = last, lead = lead, core = core, trail = trail, items = khusus.moneyItems(core) }
        position = last + 1
    end
    local replacements = {}
    local index = 1
    while index <= #tokens do
        local crossed, crossedNext = nil, nil
        if tokens[index].items ~= nil then
            crossed, crossedNext = khusus.moneyCrossed(tokens, index)
        end
        if crossed ~= nil then
            replacements[#replacements + 1] = crossed
            index = crossedNext
        elseif tokens[index].items ~= nil then
            local finish = index
            while tokens[finish + 1] ~= nil and tokens[finish + 1].items ~= nil and tokens[finish].trail == "" and tokens[finish + 1].lead == "" do
                finish = finish + 1
            end
            local marker = tokens[finish + 1]
            local handled = false
            local explicit = marker ~= nil and marker.lead == "" and tokens[finish].trail == "" and marker.core:lower() == "rupiah"
            local blocked = marker ~= nil and khusus.moneyBlockers[marker.core:lower()] == true
            if explicit or not blocked then
                for start = index, finish do
                    local items = {}
                    for walk = start, finish do
                        for _, item in ipairs(tokens[walk].items) do
                            items[#items + 1] = item
                        end
                    end
                    local value = khusus.moneyValue(items)
                    local prefix = khusus.moneyPrefix(tokens, start)
                    local afterComma = start > 2 and tokens[start - 1].core:lower() == "koma" and tokens[start - 2].items ~= nil
                    if value ~= nil and not afterComma and (explicit or prefix ~= nil or (khusus.moneyHasScale(items) and khusus.moneyCue(tokens, start))) then
                        local endPosition = tokens[finish].last - #tokens[finish].trail
                        if explicit then
                            endPosition = marker.last - #marker.trail
                        end
                        local fromPosition = tokens[start].first + #tokens[start].lead
                        if prefix ~= nil then
                            fromPosition = prefix
                        end
                        replacements[#replacements + 1] = { from = fromPosition, to = endPosition, value = value }
                        handled = true
                        break
                    end
                end
            end
            if handled and explicit then
                index = finish + 2
            else
                index = finish + 1
            end
        else
            index = index + 1
        end
    end
    if #replacements == 0 then
        return text
    end
    local parts = {}
    local cursor = 1
    for _, entry in ipairs(replacements) do
        parts[#parts + 1] = text:sub(cursor, entry.from - 1)
        parts[#parts + 1] = khusus.moneyFormat(entry.value)
        cursor = entry.to + 1
    end
    parts[#parts + 1] = text:sub(cursor)
    return table.concat(parts)
end

khusus.phoneDigitWords = {
    nol = "0", nul = "0", kosong = "0", satu = "1", dua = "2", tiga = "3", empat = "4",
    lima = "5", enam = "6", tujuh = "7", delapan = "8", sembilan = "9"
}

khusus.phoneRepeatWords = { dobel = 2, double = 2, triple = 3, tripel = 3 }

khusus.phonePlusWords = { plus = true, tambah = true }

function khusus.phoneValid(digits)
    local length = #digits
    if digits:find("^08") then
        return length >= 10 and length <= 13
    end
    if digits:find("^628") then
        return length >= 11 and length <= 14
    end
    if digits:find("^0[2-79]") then
        return length >= 9 and length <= 12
    end
    return false
end

function khusus.phoneToken(entry)
    local core = entry.core
    local lowered = core:lower()
    local digit = khusus.phoneDigitWords[lowered]
    if digit ~= nil then
        return { kind = "word", digits = digit, length = 1 }
    end
    local repeats = khusus.phoneRepeatWords[lowered]
    if repeats ~= nil then
        return { kind = "repeat", count = repeats }
    end
    if khusus.phonePlusWords[lowered] ~= nil then
        return { kind = "plus" }
    end
    if core:find("^%d+$") then
        return { kind = "digits", digits = core, length = #core }
    end
    if core:find("^%d[%d%-]*%d$") and core:find("%-") and not core:find("%-%-") then
        local firstGroup = core:match("^(%d+)%-")
        return { kind = "digits", digits = (core:gsub("%-", "")), length = #firstGroup, grouped = true }
    end
    return nil
end

function khusus.phoneJoins(current, following, crossing)
    if following == nil or following.lead ~= "" then
        return false
    end
    if current.trail == "" then
        return true
    end
    return crossing and (current.trail == "," or current.trail == ".")
end

function khusus.phoneAttempt(tokens, index, crossing)
    local first = tokens[index]
    local walk = index
    local plus = false
    if first.kind == "plus" then
        if first.lead ~= "" or not khusus.phoneJoins(first, tokens[index + 1], false) then
            return nil, index
        end
        plus = true
        walk = index + 1
    elseif first.lead == "+" and first.kind == "digits" then
        plus = true
    elseif first.lead ~= "" then
        return nil, index
    end

    local pieces = {}
    local current = walk
    while tokens[current] ~= nil and tokens[current].kind ~= nil and tokens[current].kind ~= "plus" do
        local token = tokens[current]
        if current > walk and not khusus.phoneJoins(tokens[current - 1], token, crossing) then
            break
        end
        if token.kind == "repeat" then
            local target = tokens[current + 1]
            if target == nil or not khusus.phoneJoins(token, target, false) then
                break
            end
            if not (target.kind == "word" or (target.kind == "digits" and target.length == 1 and not target.grouped)) then
                break
            end
            pieces[#pieces + 1] = { text = target.digits:rep(token.count), word = true, last = current + 1 }
            current = current + 2
        else
            pieces[#pieces + 1] = { text = token.digits, word = token.kind == "word", length = token.length, grouped = token.grouped, last = current }
            current = current + 1
        end
    end
    local runEnd = current - 1
    if #pieces == 0 then
        return nil, math.max(runEnd, index)
    end

    while #pieces > 0 do
        local tail = pieces[#pieces]
        local following = tokens[tail.last + 1]
        local dropped = false
        if tail.word and following ~= nil then
            local lowered = following.core:lower()
            if lowered == "rupiah" or (khusus.moneyWords[lowered] ~= nil and khusus.phoneDigitWords[lowered] == nil) then
                dropped = true
            elseif khusus.moneyBlockers[lowered] and #pieces > 1 then
                local rest = {}
                for position = 1, #pieces - 1 do
                    rest[#rest + 1] = pieces[position].text
                end
                dropped = khusus.phoneValid(table.concat(rest))
            end
        end
        if not dropped then
            break
        end
        pieces[#pieces] = nil
    end
    if #pieces == 0 then
        return nil, runEnd
    end

    local digits = {}
    for _, piece in ipairs(pieces) do
        digits[#digits + 1] = piece.text
    end
    digits = table.concat(digits)

    local head = pieces[1]
    if not head.word then
        if #pieces == 1 and not head.grouped then
            return nil, runEnd
        end
        if digits:find("^0") then
            if head.length < 3 or head.length > 5 then
                return nil, runEnd
            end
        elseif head.length < 2 then
            return nil, runEnd
        end
    end

    if plus then
        if not digits:find("^628") or not khusus.phoneValid(digits) then
            return nil, runEnd
        end
    elseif not khusus.phoneValid(digits) then
        return nil, runEnd
    end

    local finish = pieces[#pieces].last
    local text = digits
    if plus then
        text = "+" .. digits
    end
    return { text = text, from = first.first, to = tokens[finish].last - #tokens[finish].trail, finish = finish }, runEnd
end

function khusus.phoneNumber(text)
    local tokens = {}
    local position = 1
    local candidate = false
    while true do
        local first, last = text:find("%S+", position)
        if first == nil then
            break
        end
        local token = text:sub(first, last)
        local lead, core, trail = token:match("^([^%w]*)(.-)([^%w]*)$")
        local entry = { first = first, last = last, lead = lead, core = core, trail = trail }
        local info = khusus.phoneToken(entry)
        if info ~= nil then
            for key, value in pairs(info) do
                entry[key] = value
            end
            if info.kind == "word" or info.kind == "digits" then
                candidate = true
            end
        end
        tokens[#tokens + 1] = entry
        position = last + 1
    end
    if not candidate then
        return text
    end

    local replacements = {}
    local index = 1
    while index <= #tokens do
        if tokens[index].kind ~= nil then
            local result, runEnd = khusus.phoneAttempt(tokens, index, false)
            if result == nil then
                local crossed, crossedEnd = khusus.phoneAttempt(tokens, index, true)
                result = crossed
                if crossedEnd > runEnd then
                    runEnd = crossedEnd
                end
            end
            if result ~= nil then
                if text:sub(result.from, result.to) ~= result.text then
                    replacements[#replacements + 1] = result
                end
                index = result.finish + 1
            elseif tokens[index].kind == "plus" then
                index = index + 1
            else
                index = math.max(runEnd, index) + 1
            end
        else
            index = index + 1
        end
    end
    if #replacements == 0 then
        return text
    end
    local parts = {}
    local cursor = 1
    for _, entry in ipairs(replacements) do
        parts[#parts + 1] = text:sub(cursor, entry.from - 1)
        parts[#parts + 1] = entry.text
        cursor = entry.to + 1
    end
    parts[#parts + 1] = text:sub(cursor)
    return table.concat(parts)
end

khusus.caseTriggers = pickLogic({
    { "gunakan%s+huruf%s+besar%s+semua", "upper" },
    { "gunakan%s+huruf%s+kapital%s+semua", "upper" },
    { "huruf%s+besar%s+semua", "upper" },
    { "huruf%s+kapital%s+semua", "upper" },
    { "gunakan%s+huruf%s+kecil%s+semua", "lower" },
    { "huruf%s+kecil%s+semua", "lower" },
    { "gunakan%s+huruf%s+besar", "title" },
    { "gunakan%s+huruf%s+kapital", "title" },
    { "gunakan%s+huruf%s+kecil", "initial" }
}, {
    { "use%s+all%s+uppercase", "upper" },
    { "use%s+all%s+caps", "upper" },
    { "all%s+uppercase", "upper" },
    { "all%s+caps", "upper" },
    { "use%s+all%s+lowercase", "lower" },
    { "all%s+lowercase", "lower" },
    { "use%s+capital%s+letters", "title" },
    { "use%s+title%s+case", "title" },
    { "use%s+lowercase%s+letters", "initial" },
    { "use%s+small%s+letters", "initial" }
})

function khusus.extractCaseTrigger(text)
    local lowered = text:lower()
    for _, spec in ipairs(khusus.caseTriggers) do
        local _, finish = lowered:find("^%s*" .. spec[1])
        if finish ~= nil then
            local nextChar = text:sub(finish + 1, finish + 1)
            if nextChar == "" or nextChar:match("[%s%p]") ~= nil then
                local remainder = text:sub(finish + 1):gsub("^[%s,%.:;!%?%-]+", "")
                return remainder, spec[2]
            end
        end
    end
    return text, nil
end

function khusus.applyCase(text, mode)
    if mode == "upper" then
        return text:upper()
    end
    if mode == "lower" then
        return text:lower()
    end
    if mode == "title" or mode == "initial" then
        local converted = text:gsub("%S+", function(token)
            if token:find("://", 1, true) or token:find("@", 1, true) or token:lower():find("^www%.") then
                return token
            end
            local fixed = token:gsub("()(%a)", function(position, letter)
                if position > 1 and token:sub(position - 1, position - 1):match("[%w']") ~= nil then
                    return letter
                end
                if mode == "title" then
                    return letter:upper()
                end
                return letter:lower()
            end)
            return fixed
        end)
        return converted
    end
    return text
end

function khusus.translateTrigger(text, spec, deliver)
    if spec[2] == "palembang" then
        deliver(khusus.addPunctuation(khusus.capitalizeFirst(khusus.safeStage(khusus.palembang, text))))
        return
    end
    local source = khusus.baseCode(getLanguageTag())
    if source == "" then
        source = "auto"
    end
    khusus.translate(text, source, spec[2], deliver)
end

khusus.assistantIntents = {
    { "android.intent.action.ASSIST", "com.google.android.googlequicksearchbox" }
}
khusus.assistantWindowMs = 20000
khusus.triggerPhrases = pickLogic({
    "bukapengaturan",
    "bukasetelan",
    "bukasetting",
    "bukasettings",
    "bukaseting"
}, {
    "opensettings",
    "opensetting"
})
khusus.lastAssistantTime = nil

function khusus.openAssistant()
    for _, spec in ipairs(khusus.assistantIntents) do
        local opened = pcall(function()
            local intent = Intent(spec[1])
            if spec[2] ~= "" then
                intent.setPackage(spec[2])
            end
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            this.startActivity(intent)
        end)
        if opened then
            return true
        end
    end
    return false
end

function khusus.callAssistant()
    if khusus.openAssistant() then
        khusus.lastAssistantTime = System.currentTimeMillis()
        return
    end
    khusus.lastAssistantTime = nil
    khusus.openMainSettings(function()
        khusus.speakAfterMicrophone(T("Asisten gagal dipanggil.", "The assistant could not be called."))
    end)
end

khusus.commandLeading = pickLogic({ "tolong", "coba", "ayo", "silakan", "silahkan" }, { "please", "just", "hey", "can you", "could you", "would you", "i want to", "i would like to" })
khusus.commandVerbs = pickLogic({ "bukakan", "bukalah", "buka", "jalankan", "luncurkan", "masuk ke", "pergi ke", "tampilkan", "open" }, { "open", "launch", "run", "start", "go to", "show me", "show", "take me to" })
khusus.commandFillers = pickLogic({ "aplikasi", "app", "program", "ke" }, { "the", "my", "app", "application", "program", "to" })
khusus.commandTrailing = pickLogic({ "dong", "donk", "ya", "yah", "sekarang", "tolong", "saja", "aja", "please" }, { "please", "now", "for me", "app", "application", "thanks" })
khusus.settingsWords = pickLogic({ "pengaturan", "setelan", "setting", "settings", "seting" }, { "settings", "setting" })
khusus.settingsFillers = pickLogic({ "bawaan", "hp", "ponsel", "handphone", "telepon", "perangkat", "sistem", "android", "ke", "dalam", "yang" }, { "phone", "default", "system", "android", "device", "the", "my", "for", "of", "to", "main", "general" })
khusus.assistantPhrases = pickLogic({
    "panggilasisten",
    "bukaasisten",
    "asistengoogle",
    "googleasisten",
    "okgoogle",
    "okaygoogle",
    "hallogoogle",
    "heygoogle",
    "panggilgemini"
}, {
    "callassistant",
    "openassistant",
    "googleassistant",
    "assistantgoogle",
    "okgoogle",
    "okaygoogle",
    "hellogoogle",
    "heygoogle",
    "callgemini"
})
khusus.voiceMessagePhrases = pickLogic({
    "pesansuara"
}, {
    "voicemessage"
})
khusus.sendPhrases = pickLogic({
    "kirim"
}, {
    "send"
})
khusus.fieldPhrases = pickLogic({
    ["pindahkeawal"] = "start",
    ["pindahkeakhir"] = "end",
    ["pilihsemua"] = "all",
    ["pilihkalimatterakhir"] = "lastsentence",
    ["tempel"] = "paste",
    ["potong"] = "cut"
}, {
    ["movetostart"] = "start",
    ["movetobeginning"] = "start",
    ["movetoend"] = "end",
    ["selectall"] = "all",
    ["selectlastsentence"] = "lastsentence",
    ["paste"] = "paste",
    ["cut"] = "cut"
})
khusus.voiceMessageWindowMs = 600000
khusus.voiceMessageKey = "pesan_suara_mulai"
khusus.voiceMessageActiveKey = "pesan_suara_aktif"
khusus.voiceMessageSteps = {
    "Pesan suara, Tombol.*$100",
    "%[usap ke atas]$100"
}
khusus.sendMessageSteps = {
    "Kirim|Send|Uploading*$100"
}
khusus.generalSettingsAction = "android.settings.SETTINGS"
khusus.languagePackAction = "android.settings.VOICE_INPUT_SETTINGS"
khusus.languagePackComponents = {
    { "com.google.android.googlequicksearchbox", "com.google.android.voicesearch.greco3.languagepack.InstallActivity" },
    { "com.google.android.googlequicksearchbox", "com.google.android.apps.gsa.settingsui.VoiceSearchPreferences" }
}
khusus.appCount = nil

khusus.settingsList = {
    { keys = { "wifi", "jaringanwifi" }, action = "android.settings.WIFI_SETTINGS", name = "Wi-Fi" },
    { keys = { "bluetooth", "blutut", "bluetoot" }, action = "android.settings.BLUETOOTH_SETTINGS", name = T("Bluetooth", "Bluetooth") },
    { keys = { "modepesawat", "modepenerbangan", "pesawat", "airplanemode", "flightmode", "airplane" }, action = "android.settings.AIRPLANE_MODE_SETTINGS", name = T("Mode pesawat", "Airplane mode") },
    { keys = { "suara", "volume", "bunyi", "nadadering", "dering", "audio", "sound", "sounds", "ringtone" }, action = "android.settings.SOUND_SETTINGS", name = T("Suara", "Sound") },
    { keys = { "layar", "tampilan", "kecerahan", "display", "brightness", "screen" }, action = "android.settings.DISPLAY_SETTINGS", name = T("Layar", "Display") },
    { keys = { "baterai", "batere", "daya", "battery" }, action = "android.intent.action.POWER_USAGE_SUMMARY", name = T("Baterai", "Battery") },
    { keys = { "hematbaterai", "penghematbaterai", "penghematdaya", "hematdaya", "batterysaver", "powersaver" }, action = "android.settings.BATTERY_SAVER_SETTINGS", name = T("Penghemat baterai", "Battery saver") },
    { keys = { "penyimpanan", "memori", "storage" }, action = "android.settings.INTERNAL_STORAGE_SETTINGS", name = T("Penyimpanan", "Storage") },
    { keys = { "aksesibilitas", "accessibility" }, action = "android.settings.ACCESSIBILITY_SETTINGS", name = T("Aksesibilitas", "Accessibility") },
    { keys = { "bahasa", "language", "languages" }, action = "android.settings.LOCALE_SETTINGS", name = T("Bahasa", "Language") },
    { keys = { "tanggaldanwaktu", "tanggalwaktu", "tanggal", "waktu", "zonawaktu", "dateandtime", "datetime", "date", "time", "timezone" }, action = "android.settings.DATE_SETTINGS", name = T("Tanggal dan waktu", "Date and time") },
    { keys = { "lokasi", "gps", "location" }, action = "android.settings.LOCATION_SOURCE_SETTINGS", name = T("Lokasi", "Location") },
    { keys = { "keamanan", "security" }, action = "android.settings.SECURITY_SETTINGS", name = T("Keamanan", "Security") },
    { keys = { "privasi" }, action = "android.settings.PRIVACY_SETTINGS", name = T("Privasi", "Privacy") },
    { keys = { "nfc" }, action = "android.settings.NFC_SETTINGS", name = "NFC" },
    { keys = { "keyboard", "papanketik", "masukan", "metodeinput" }, action = "android.settings.INPUT_METHOD_SETTINGS", name = T("Keyboard", "Keyboard") },
    { keys = { "tentangponsel", "tentangtelepon", "tentanghp", "infoperangkat", "infoponsel", "versiandroid", "aboutphone", "aboutdevice", "deviceinfo", "phoneinfo", "androidversion" }, action = "android.settings.DEVICE_INFO_SETTINGS", name = T("Tentang ponsel", "About phone") },
    { keys = { "aplikasi", "daftaraplikasi", "kelolaaplikasi", "pengelolaaplikasi", "apps", "applications", "manageapps", "applist" }, action = "android.settings.MANAGE_APPLICATIONS_SETTINGS", name = T("Aplikasi", "Apps"), prefixOnly = true },
    { keys = { "akun", "sinkronisasi", "akundansinkronisasi", "accounts", "account", "sync", "accountsandsync" }, action = "android.settings.SYNC_SETTINGS", name = T("Akun dan sinkronisasi", "Accounts and sync"), prefixOnly = true },
    { keys = { "jaringan", "jaringanseluler", "dataseluler", "seluler", "koneksi", "network", "networks", "mobilenetwork", "mobiledata", "cellular", "connections" }, action = "android.settings.WIRELESS_SETTINGS", name = T("Jaringan dan koneksi", "Network and connections") },
    { keys = { "penggunaandata", "kuotadata", "datausage" }, action = "android.settings.DATA_USAGE_SETTINGS", name = T("Penggunaan data", "Data usage") },
    { keys = { "hotspot", "tethering", "modem" }, action = "android.settings.TETHER_SETTINGS", name = T("Hotspot dan tethering", "Hotspot and tethering") },
    { keys = { "jangandiganggu", "tidakganggu", "tidakdiganggu", "dnd", "donotdisturb" }, action = "android.settings.ZEN_MODE_SETTINGS", name = T("Jangan ganggu", "Do not disturb") },
    { keys = { "notifikasi", "pemberitahuan", "notifications", "notification" }, action = "android.settings.ALL_APPS_NOTIFICATION_SETTINGS", name = T("Notifikasi", "Notifications") },
    { keys = { "opsipengembang", "pengembang", "developer", "developeroptions" }, action = "android.settings.APPLICATION_DEVELOPMENT_SETTINGS", name = T("Opsi pengembang", "Developer options") },
    { keys = { "paketbahasa", "paketbahasaoffline", "bahasaoffline", "unduhbahasa", "unduhpaketbahasa", "pengunduhanbahasa", "pengunduhanpaketbahasa", "paketsuara", "suaraoffline", "pengenalansuara", "downloadlanguage", "languagepack", "offlinelanguage", "offlinespeech", "voicepack", "speechrecognition" }, action = khusus.languagePackAction, name = T("Paket bahasa offline", "Offline language pack"), languagePack = true, prefixOnly = true }
}

khusus.appAliases = {
    wa = { "whatsapp" },
    ig = { "instagram" },
    fb = { "facebook" },
    yt = { "youtube" },
    tele = { "telegram" },
    kamera = { "camera" },
    camera = { "kamera" },
    kalkulator = { "calculator" },
    calculator = { "kalkulator" },
    kontak = { "contacts" },
    contacts = { "kontak" },
    telepon = { "phone" },
    phone = { "telepon" },
    pesan = { "messages", "message" },
    messages = { "pesan" },
    galeri = { "gallery" },
    gallery = { "galeri" },
    jam = { "clock" },
    clock = { "jam" },
    peta = { "maps" },
    maps = { "peta" },
    catatan = { "notes" },
    notes = { "catatan" },
    kalender = { "calendar" },
    calendar = { "kalender" },
    berkas = { "files" },
    files = { "berkas" }
}

function khusus.squeeze(text)
    return (tostring(text):lower():gsub("[^%w]", ""))
end

function khusus.normalizeSpoken(text)
    local spoken = tostring(text):lower():gsub("[^%w%s]", " ")
    spoken = spoken:gsub("%s+", " ")
    return (spoken:match("^%s*(.-)%s*$"))
end

function khusus.stripLeading(text, words)
    local changed = true
    while changed do
        changed = false
        for _, word in ipairs(words) do
            if text == word then
                text = ""
                changed = true
            else
                local rest = text:match("^" .. word .. "%s+(.+)$")
                if rest ~= nil then
                    text = rest
                    changed = true
                end
            end
        end
    end
    return text
end

function khusus.stripTrailing(text, words)
    local changed = true
    while changed do
        changed = false
        for _, word in ipairs(words) do
            if text == word then
                text = ""
                changed = true
            else
                local rest = text:match("^(.+)%s+" .. word .. "$")
                if rest ~= nil then
                    text = rest
                    changed = true
                end
            end
        end
    end
    return text
end

function khusus.loadApps()
    local apps = {}
    local seen = {}
    local function add(label, pkg, cls)
        local key = khusus.squeeze(label)
        local id = pkg .. "/" .. cls
        if key ~= "" and not seen[id] then
            seen[id] = true
            apps[#apps + 1] = { label = label, key = key, pkg = pkg, cls = cls }
        end
    end
    pcall(function()
        local pm = this.getPackageManager()
        local intent = Intent("android.intent.action.MAIN")
        intent.addCategory("android.intent.category.LAUNCHER")
        local list = pm.queryIntentActivities(intent, 0)
        for index = 0, list.size() - 1 do
            pcall(function()
                local info = list.get(index)
                add(tostring(info.loadLabel(pm)), tostring(info.activityInfo.packageName), tostring(info.activityInfo.name))
            end)
        end
    end)
    if #apps == 0 then
        pcall(function()
            local pm = this.getPackageManager()
            local installed = pm.getInstalledApplications(0)
            for index = 0, installed.size() - 1 do
                pcall(function()
                    local item = installed.get(index)
                    local pkg = tostring(item.packageName)
                    local launch = pm.getLaunchIntentForPackage(pkg)
                    if launch ~= nil then
                        add(tostring(pm.getApplicationLabel(item)), pkg, tostring(launch.getComponent().getClassName()))
                    end
                end)
            end
        end)
    end
    return apps
end

function khusus.matchApp(query, apps)
    local primary = khusus.squeeze(query)
    if primary == "" then
        return nil, 0
    end
    local variants = { primary }
    local aliases = khusus.appAliases[primary]
    if aliases ~= nil then
        for _, alias in ipairs(aliases) do
            variants[#variants + 1] = khusus.squeeze(alias)
        end
    end
    local words = {}
    for word in query:gmatch("%S+") do
        words[#words + 1] = khusus.squeeze(word)
    end
    local best = nil
    local bestScore = 0
    for _, app in ipairs(apps) do
        local label = app.key
        local score = 0
        for _, q in ipairs(variants) do
            local value = 0
            if q ~= "" then
                if label == q then
                    value = 100
                elseif #q >= 3 and label:sub(1, #q) == q then
                    value = 75 + 10 * #q / #label
                elseif #q >= 3 and label:find(q, 1, true) ~= nil then
                    value = 60 + 10 * #q / #label
                elseif #label >= 4 and q:find(label, 1, true) ~= nil then
                    value = 55
                end
            end
            if value > score then
                score = value
            end
        end
        if score == 0 and #words > 1 then
            local all = true
            for _, word in ipairs(words) do
                if word == "" or label:find(word, 1, true) == nil then
                    all = false
                    break
                end
            end
            if all then
                score = 56
            end
        end
        if score > bestScore or (score > 0 and score == bestScore and best ~= nil and #label < #best.key) then
            best = app
            bestScore = score
        end
    end
    if bestScore < 55 then
        return nil, 0
    end
    return best, bestScore
end

function khusus.matchSettings(sub, prefixed)
    local squeezed = khusus.squeeze(sub)
    if squeezed == "" then
        return nil, 0
    end
    local best = nil
    local bestScore = 0
    for _, entry in ipairs(khusus.settingsList) do
        if prefixed or not entry.prefixOnly then
            for _, key in ipairs(entry.keys) do
                local score = 0
                if squeezed == key then
                    score = 95
                elseif #key >= 4 and squeezed:find(key, 1, true) ~= nil then
                    if prefixed then
                        score = 60 + math.min(#key, 20)
                    else
                        score = 45 + math.min(#key, 10)
                    end
                end
                if score > bestScore then
                    best = entry
                    bestScore = score
                end
            end
        end
    end
    return best, bestScore
end

function khusus.settingsCommand(entry)
    return { kind = "settings", action = entry.action, name = entry.name, languagePack = entry.languagePack }
end

function khusus.resolveTarget(rest, getApps)
    if not logicIndonesian then
        local head = rest:match("^(.+)%s+settings?$")
        if head ~= nil and head ~= "" then
            rest = "settings " .. head
        end
    end
    for _, word in ipairs(khusus.settingsWords) do
        local sub = nil
        if rest == word then
            sub = ""
        else
            sub = rest:match("^" .. word .. "%s+(.+)$")
        end
        if sub ~= nil then
            if sub == "" then
                return { kind = "mainsettings" }, 90
            end
            local entry, score = khusus.matchSettings(sub, true)
            if entry ~= nil then
                return khusus.settingsCommand(entry), score
            end
            local stripped = khusus.stripLeading(sub, khusus.settingsFillers)
            stripped = khusus.stripTrailing(stripped, khusus.settingsFillers)
            if stripped == "" then
                return { kind = "settings", action = khusus.generalSettingsAction, name = T("Pengaturan HP", "Phone settings") }, 90
            end
            entry, score = khusus.matchSettings(stripped, true)
            if entry ~= nil then
                return khusus.settingsCommand(entry), score
            end
            local app, appScore = khusus.matchApp(stripped, getApps())
            if app ~= nil then
                return { kind = "appinfo", pkg = app.pkg, label = app.label }, 50
            end
            return { kind = "settings", action = khusus.generalSettingsAction, name = T("Pengaturan HP", "Phone settings"), unknown = stripped }, 45
        end
    end
    local app, appScore = khusus.matchApp(rest, getApps())
    local entry, entryScore = khusus.matchSettings(rest, false)
    if app ~= nil and (entry == nil or appScore >= entryScore) then
        return { kind = "app", pkg = app.pkg, cls = app.cls, label = app.label }, appScore
    end
    if entry ~= nil then
        return khusus.settingsCommand(entry), entryScore
    end
    return nil, 0
end

function khusus.extractCommandTarget(spoken)
    local text = khusus.stripLeading(spoken, khusus.commandLeading)
    for _, verb in ipairs(khusus.commandVerbs) do
        local rest = text:match("^" .. verb .. "%s+(.+)$")
        if rest ~= nil then
            rest = khusus.stripLeading(rest, khusus.commandFillers)
            rest = khusus.stripTrailing(rest, khusus.commandTrailing)
            if rest == "" then
                return nil
            end
            return rest
        end
    end
    return nil
end

function khusus.matchCommand(list)
    khusus.appCount = nil
    if list == nil then
        return nil
    end
    local apps = nil
    local function getApps()
        if apps == nil then
            apps = khusus.loadApps()
            khusus.appCount = #apps
        end
        return apps
    end
    local bestCommand = nil
    local bestScore = 0
    for index = 0, list.size() - 1 do
        local spoken = khusus.normalizeSpoken(list.get(index))
        local squeezed = khusus.squeeze(spoken)
        for _, phrase in ipairs(khusus.assistantPhrases) do
            if squeezed:find(phrase, 1, true) ~= nil then
                return { kind = "assistant" }
            end
        end
        for _, phrase in ipairs(khusus.voiceMessagePhrases) do
            if squeezed:find(phrase, 1, true) ~= nil then
                return { kind = "voicemessage" }
            end
        end
        local core = khusus.stripTrailing(khusus.stripLeading(spoken, khusus.commandLeading), khusus.commandTrailing)
        if khusus.isExactSend(khusus.squeeze(core)) then
            return { kind = "send" }
        end
        local rest = khusus.extractCommandTarget(spoken)
        if rest ~= nil then
            local command, score = khusus.resolveTarget(rest, getApps)
            if command ~= nil and score > bestScore then
                bestCommand = command
                bestScore = score
            end
        end
    end
    return bestCommand
end

function khusus.isExactTrigger(squeezed)
    for _, phrase in ipairs(khusus.triggerPhrases) do
        if squeezed == phrase then
            return true
        end
    end
    return false
end

function khusus.isExactAssistant(squeezed)
    for _, phrase in ipairs(khusus.assistantPhrases) do
        if squeezed == phrase or squeezed == phrase .. "google" then
            return true
        end
    end
    return false
end

function khusus.isExactVoiceMessage(squeezed)
    for _, phrase in ipairs(khusus.voiceMessagePhrases) do
        if squeezed == phrase then
            return true
        end
    end
    return false
end

function khusus.isExactSend(squeezed)
    for _, phrase in ipairs(khusus.sendPhrases) do
        if squeezed == phrase then
            return true
        end
    end
    return false
end

function khusus.editCommandAccepted(command, score)
    if command.kind == "mainsettings" then
        return true
    end
    if command.kind == "app" then
        return score >= 60
    end
    if command.kind == "appinfo" then
        return true
    end
    if command.kind == "settings" then
        return command.unknown == nil and score >= 60
    end
    return false
end

function khusus.matchEditCommand(list)
    khusus.appCount = nil
    if list == nil then
        return nil
    end
    local apps = nil
    local function getApps()
        if apps == nil then
            apps = khusus.loadApps()
            khusus.appCount = #apps
        end
        return apps
    end
    local bestCommand = nil
    local bestScore = 0
    for index = 0, list.size() - 1 do
        local spoken = khusus.normalizeSpoken(list.get(index))
        local core = khusus.stripTrailing(khusus.stripLeading(spoken, khusus.commandLeading), khusus.commandTrailing)
        local squeezed = khusus.squeeze(core)
        if khusus.isExactTrigger(squeezed) then
            return { kind = "mainsettings" }
        end
        if khusus.isExactAssistant(squeezed) then
            return { kind = "assistant" }
        end
        if khusus.isExactVoiceMessage(squeezed) then
            return { kind = "voicemessage" }
        end
        if khusus.isExactSend(squeezed) then
            return { kind = "send" }
        end
        local fieldAction = khusus.fieldPhrases[squeezed]
        if fieldAction ~= nil then
            return { kind = "field", action = fieldAction }
        end
        local rest = khusus.extractCommandTarget(spoken)
        if rest ~= nil then
            local command, score = khusus.resolveTarget(rest, getApps)
            if command ~= nil and khusus.editCommandAccepted(command, score) and score > bestScore then
                bestCommand = command
                bestScore = score
            end
        end
    end
    return bestCommand
end

function khusus.startSettings(action)
    return pcall(function()
        local intent = Intent(action)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        this.startActivity(intent)
    end)
end

function khusus.startComponent(pkg, cls)
    return pcall(function()
        local intent = Intent()
        intent.setClassName(pkg, cls)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        this.startActivity(intent)
    end)
end

function khusus.openLanguagePackDownload()
    for _, target in ipairs(khusus.languagePackComponents) do
        if khusus.startComponent(target[1], target[2]) then
            return true
        end
    end
    if khusus.startSettings(khusus.languagePackAction) then
        return true
    end
    return khusus.startSettings(khusus.generalSettingsAction)
end

function khusus.runVoiceMessage()
    local clicked = false
    pcall(function()
        if service.click({ khusus.voiceMessageSteps }) then
            clicked = true
        end
    end)
    if not clicked then
        khusus.clearVoiceMessage()
        khusus.speakAfterMicrophone(T("Tombol pesan suara tidak ditemukan.", "The voice message button was not found."))
        return
    end
    khusus.markVoiceMessage()
    pcall(function()
        this.execute("jeda tts utama")
    end)
end

function khusus.markVoiceMessage()
    pcall(function()
        getPrefs().edit().putBoolean(khusus.voiceMessageActiveKey, true).apply()
    end)
    pcall(function()
        getPrefs().edit().putString(khusus.voiceMessageKey, tostring(System.currentTimeMillis())).apply()
    end)
end

function khusus.clearVoiceMessage()
    pcall(function()
        getPrefs().edit().remove(khusus.voiceMessageActiveKey).remove(khusus.voiceMessageKey).apply()
    end)
end

function khusus.clickSend()
    local clicked = false
    pcall(function()
        if service.click({ khusus.sendMessageSteps }) then
            clicked = true
        end
    end)
    if not clicked then
        khusus.speakAfterMicrophone(T("Tombol kirim tidak ditemukan.", "The send button was not found."))
        return
    end
    pcall(function()
        service.play("gesture_end")
    end)
end

function khusus.sendVoiceMessage()
    local active = false
    pcall(function()
        active = getPrefs().getBoolean(khusus.voiceMessageActiveKey, false) == true
    end)
    if not active then
        return false
    end
    local started = nil
    pcall(function()
        started = tonumber(tostring(getPrefs().getString(khusus.voiceMessageKey, "")))
    end)
    khusus.clearVoiceMessage()
    if started ~= nil and System.currentTimeMillis() - started > khusus.voiceMessageWindowMs then
        return false
    end
    khusus.clickSend()
    return true
end

function khusus.unitCount(text, limit)
    local count = 0
    local index = 1
    while index <= limit do
        local byte = text:byte(index)
        if byte >= 240 then
            count = count + 2
            index = index + 4
        elseif byte >= 224 then
            count = count + 1
            index = index + 3
        elseif byte >= 192 then
            count = count + 1
            index = index + 2
        else
            count = count + 1
            index = index + 1
        end
    end
    return count
end

function khusus.byteLimit(text, units)
    local count = 0
    local index = 1
    while index <= #text and count < units do
        local byte = text:byte(index)
        if byte >= 240 then
            count = count + 2
            index = index + 4
        elseif byte >= 224 then
            count = count + 1
            index = index + 3
        elseif byte >= 192 then
            count = count + 1
            index = index + 2
        else
            count = count + 1
            index = index + 1
        end
    end
    return index - 1
end

function khusus.lastSentenceRange(text)
    local finish = #text
    while finish > 0 and text:sub(finish, finish):match("%s") do
        finish = finish - 1
    end
    if finish == 0 then
        return nil, nil
    end
    local cursor = finish
    while cursor > 0 and text:sub(cursor, cursor):match("[%.!%?]") do
        cursor = cursor - 1
    end
    local begin = 1
    for index = cursor, 1, -1 do
        local mark = text:sub(index, index)
        if mark == "\n" or (mark:match("[%.!%?]") and text:sub(index + 1, index + 1):match("%s")) then
            begin = index + 1
            break
        end
    end
    while begin <= finish and text:sub(begin, begin):match("%s") do
        begin = begin + 1
    end
    if begin > finish then
        return nil, nil
    end
    return begin, finish
end

function khusus.fieldRead()
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        return nil
    end
    local hinted = false
    pcall(function()
        hinted = node.isShowingHintText() == true
    end)
    local field = { node = node, text = "", length = 0 }
    if not hinted then
        pcall(function()
            local value = node.getText()
            if value ~= nil then
                local text = tostring(value)
                field.text = text
                field.length = khusus.unitCount(text, #text)
            end
        end)
    end
    return field
end

function khusus.fieldSelection(field)
    local first = -1
    local last = -1
    pcall(function()
        first = field.node.getTextSelectionStart()
        last = field.node.getTextSelectionEnd()
    end)
    if first < 0 or last < 0 then
        return nil, nil
    end
    if first > last then
        first, last = last, first
    end
    if last > field.length then
        last = field.length
    end
    if first >= last then
        return nil, nil
    end
    return first, last
end

function khusus.fieldSelect(node, first, last)
    local done, result = pcall(function()
        local bundle = Bundle()
        bundle.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, first)
        bundle.putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, last)
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, bundle)
    end)
    return done and result == true
end

function khusus.fieldSetText(node, value)
    local done, result = pcall(function()
        local bundle = Bundle()
        bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
    end)
    return done and result == true
end

function khusus.clipboardText()
    local text = ""
    pcall(function()
        local manager = this.getSystemService(Context.CLIPBOARD_SERVICE)
        local clip = manager.getPrimaryClip()
        if clip ~= nil and clip.getItemCount() > 0 then
            local piece = clip.getItemAt(0).coerceToText(this)
            if piece ~= nil then
                text = tostring(piece)
            end
        end
    end)
    return text
end

function khusus.runFieldCommand(action)
    local say = khusus.speakAfterMicrophone
    local field = khusus.fieldRead()
    if field == nil then
        say(T("Tidak ada teks yang fokus.", "No text is focused."))
        return
    end
    if action == "paste" then
        local done, result = pcall(function()
            return field.node.performAction(AccessibilityNodeInfo.ACTION_PASTE)
        end)
        local pasted = done and result == true
        if not pasted then
            local clip = khusus.clipboardText()
            if clip ~= "" then
                pasted = pcall(function()
                    service.insertText(field.node, clip)
                end)
            end
        end
        if pasted then
            khusus.lastInserted = nil
            say(T("Teks ditempel.", "Text pasted."))
        else
            say(T("Teks gagal ditempel.", "The text could not be pasted."))
        end
        return
    end
    if action == "cut" then
        local first, last = khusus.fieldSelection(field)
        if first == nil then
            say(T("Tidak ada teks yang dipilih.", "No text is selected."))
            return
        end
        local done, result = pcall(function()
            return field.node.performAction(AccessibilityNodeInfo.ACTION_CUT)
        end)
        local cut = done and result == true
        if not cut then
            local from = khusus.byteLimit(field.text, first)
            local to = khusus.byteLimit(field.text, last)
            local chosen = field.text:sub(from + 1, to)
            local remaining = field.text:sub(1, from) .. field.text:sub(to + 1)
            if khusus.copyToClipboard(chosen) and khusus.fieldSetText(field.node, remaining) then
                khusus.fieldSelect(field.node, first, first)
                cut = true
            end
        end
        if cut then
            khusus.lastInserted = nil
            say(T("Teks dipotong.", "Text cut."))
        else
            say(T("Teks gagal dipotong.", "The text could not be cut."))
        end
        return
    end
    if field.length == 0 then
        say(T("Kotak teks kosong.", "The text box is empty."))
        return
    end
    local first = 0
    local last = 0
    local success = ""
    if action == "start" then
        success = T("Kursor di awal teks.", "Cursor at the start of the text.")
    elseif action == "end" then
        first = field.length
        last = field.length
        success = T("Kursor di akhir teks.", "Cursor at the end of the text.")
    elseif action == "all" then
        last = field.length
        success = T("Semua teks dipilih.", "All text selected.")
    elseif action == "lastsentence" then
        local from, to = khusus.lastSentenceRange(field.text)
        if from == nil then
            say(T("Tidak ada kalimat.", "There is no sentence."))
            return
        end
        first = khusus.unitCount(field.text, from - 1)
        last = khusus.unitCount(field.text, to)
        success = T("Kalimat terakhir dipilih.", "Last sentence selected.")
    else
        return
    end
    if khusus.fieldSelect(field.node, first, last) then
        say(success)
    else
        say(T("Kursor atau pilihan gagal diatur.", "The cursor or selection could not be set."))
    end
end

function khusus.runCommand(command)
    if command.kind == "assistant" then
        khusus.callAssistant()
        return
    end
    if command.kind == "voicemessage" then
        khusus.runVoiceMessage()
        return
    end
    if command.kind == "send" then
        khusus.clickSend()
        return
    end
    if command.kind == "field" then
        khusus.runFieldCommand(command.action)
        return
    end
    if command.kind == "mainsettings" then
        khusus.openMainSettings(function()
            khusus.speakAfterMicrophone(T("Asisten aktif.", "Assistant is on."))
        end)
        return
    end
    if command.kind == "app" then
        service.speak(T("Membuka ", "Opening ") .. command.label .. ".")
        local started = pcall(function()
            local intent = Intent("android.intent.action.MAIN")
            intent.addCategory("android.intent.category.LAUNCHER")
            intent.setClassName(command.pkg, command.cls)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            this.startActivity(intent)
        end)
        if not started then
            khusus.speakAfterMicrophone(T("Aplikasi ", "App ") .. command.label .. T(" gagal dibuka.", " could not be opened."))
        end
        return
    end
    if command.kind == "appinfo" then
        service.speak(T("Membuka info aplikasi ", "Opening app info for ") .. command.label .. ".")
        local started = pcall(function()
            local intent = Intent("android.settings.APPLICATION_DETAILS_SETTINGS", Uri.parse("package:" .. command.pkg))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            this.startActivity(intent)
        end)
        if not started then
            khusus.speakAfterMicrophone(T("Info aplikasi ", "App info for ") .. command.label .. T(" gagal dibuka.", " could not be opened."))
        end
        return
    end
    if command.kind == "settings" then
        if command.unknown ~= nil then
            service.speak(T("Pengaturan ", "Setting ") .. command.unknown .. T(" tidak dikenali. Membuka pengaturan utama HP.", " was not recognized. Opening the main phone settings."))
        else
            service.speak(T("Membuka pengaturan ", "Opening settings for ") .. command.name .. ".")
        end
        if command.languagePack and khusus.openLanguagePackDownload() then
            khusus.speakAfterMicrophone(T("Pilih Pengenalan suara offline, lalu unduh Bahasa Indonesia.", "Choose Offline speech recognition, then download your language."))
            return
        end
        if khusus.startSettings(command.action) then
            return
        end
        if command.action ~= khusus.generalSettingsAction and khusus.startSettings(khusus.generalSettingsAction) then
            khusus.speakAfterMicrophone(T("Pengaturan ", "Setting ") .. command.name .. T(" tidak tersedia di HP ini. Pengaturan utama HP dibuka.", " is not available on this phone. The main phone settings are opened."))
            return
        end
        khusus.speakAfterMicrophone(T("Pengaturan HP gagal dibuka.", "The phone settings could not be opened."))
    end
end

function khusus.engineExtras(intent)
    intent.putExtra("android.speech.extra.PREFER_OFFLINE", true)
    pcall(function()
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
    end)
    pcall(function()
        intent.putExtra("android.speech.extra.MASK_OFFENSIVE_WORDS", false)
    end)
end

khusus.noiseKeys = { "noise_suppression", "noise_reduction" }
khusus.noiseSaved = nil

function khusus.audioManager()
    local found, manager = pcall(function()
        return this.getSystemService(Context.AUDIO_SERVICE)
    end)
    if found then
        return manager
    end
    return nil
end

function khusus.noiseOn()
    if khusus.noiseSaved ~= nil then
        return
    end
    local manager = khusus.audioManager()
    if manager == nil then
        return
    end
    local saved = {}
    for _, key in ipairs(khusus.noiseKeys) do
        local original = "off"
        pcall(function()
            local current = tostring(manager.getParameters(key))
            local value = current:match("^" .. key .. "=(%a+)")
            if value ~= nil then
                original = value
            end
        end)
        saved[key] = original
        pcall(function()
            manager.setParameters(key .. "=on")
        end)
    end
    khusus.noiseSaved = saved
end

function khusus.noiseOff()
    local saved = khusus.noiseSaved
    if saved == nil then
        return
    end
    khusus.noiseSaved = nil
    local manager = khusus.audioManager()
    if manager == nil then
        return
    end
    for key, original in pairs(saved) do
        pcall(function()
            manager.setParameters(key .. "=" .. original)
        end)
    end
end

function khusus.recognitionFailed()
    khusus.lastAssistantTime = nil
    khusus.openMainSettings(function()
        khusus.speakAfterMicrophone(T("Pengenalan suara gagal. Periksa paket bahasa offline.", "Speech recognition failed. Check the offline language pack."))
    end)
end

function khusus.handleNoEditText()
    local now = System.currentTimeMillis()
    local last = khusus.lastAssistantTime
    if last ~= nil and now - last <= khusus.assistantWindowMs then
        khusus.lastAssistantTime = nil
        return false
    end
    if khusus.listenForTrigger() then
        return true
    end
    khusus.recognitionFailed()
    return true
end

function khusus.languageIndex(code, withAuto)
    if withAuto and code == "auto" then
        return 1
    end
    for i, item in ipairs(khusus.languages) do
        if item.code == code then
            if withAuto then
                return i + 1
            end
            return i
        end
    end
    if withAuto then
        return 1
    end
    return 2
end

function khusus.sourceLang()
    return tostring(getPrefs().getString("terjemah_asal", "auto"))
end

function khusus.targetLang()
    return tostring(getPrefs().getString("terjemah_tujuan", "en"))
end

function khusus.languageName(code)
    if code == "auto" then
        return T("Deteksi otomatis", "Auto detect")
    end
    for _, item in ipairs(khusus.languages) do
        if item.code == code then
            return item.name
        end
    end
    return code
end

function khusus.showForm(title, specs, checkLabel, checkedValue, saveLabel, onSave, onBack)
    local layout = LinearLayout(this)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(48, 32, 48, 16)
    local fields = {}
    for i, spec in ipairs(specs) do
        local field = EditText(this)
        field.setHint(spec.hint)
        field.setContentDescription(spec.hint)
        if spec.text ~= nil then
            field.setText(spec.text)
        end
        if spec.multiline then
            field.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_MULTI_LINE)
            field.setMinLines(3)
            field.setMaxLines(8)
        end
        layout.addView(field)
        fields[i] = field
    end
    local box = nil
    if checkLabel ~= nil then
        box = CheckBox(this)
        box.setText(checkLabel)
        box.setChecked(checkedValue == true)
        layout.addView(box)
    end
    local scroll = ScrollView(this)
    scroll.addView(layout)
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setView(scroll)
    builder.setPositiveButton(saveLabel, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            local values = {}
            for i, field in ipairs(fields) do
                values[i] = tostring(field.getText())
            end
            local checked = false
            if box ~= nil then
                checked = box.isChecked()
            end
            dialog.dismiss()
            onSave(values, checked)
        end
    })
    builder.setNegativeButton(T("Batal", "Cancel"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            onBack()
        end
    })
    presentDialog(builder)
end

function khusus.showConfirm(title, message, onYes, onBack)
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setMessage(message)
    builder.setPositiveButton(T("Ya", "Yes"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            onYes()
        end
    })
    builder.setNegativeButton(T("Batal", "Cancel"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            onBack()
        end
    })
    presentDialog(builder)
end

function khusus.preview(text, limit)
    text = tostring(text or ""):gsub("%s+", " ")
    if #text > limit then
        text = text:sub(1, limit) .. "..."
    end
    return text
end

function khusus.showMacroForm(index, prefill)
    local list = khusus.getMacros()
    local current = nil
    if index ~= nil then
        current = list[index]
    end
    local trigger = ""
    local content = ""
    if prefill ~= nil then
        trigger = prefill[1]
        content = prefill[2]
    elseif current ~= nil then
        trigger = current.trigger
        content = current.content
    end
    local title = T("Tambah macro", "Add macro")
    if index ~= nil then
        title = T("Ubah macro", "Edit macro")
    end
    khusus.showForm(title, {
        { hint = T("Nama pemicu (trigger)", "Trigger name"), text = trigger },
        { hint = T("Isi macro", "Macro content"), text = content, multiline = true }
    }, nil, nil, T("Simpan", "Save"), function(values)
        local newTrigger = khusus.trim(values[1])
        local newContent = values[2]
        if newTrigger == "" then
            service.speak(T("Nama pemicu tidak boleh kosong.", "The trigger name must not be empty."))
            khusus.showMacroForm(index, values)
            return
        end
        if index == nil and #list >= khusus.maxMacro then
            service.speak(T("Batas maksimum 1000 macro tercapai.", "The maximum of 1000 macros has been reached."))
            khusus.showMacroMenu()
            return
        end
        local normalized = khusus.normalizeToken(newTrigger)
        for i, item in ipairs(list) do
            if i ~= index and khusus.normalizeToken(item.trigger) == normalized then
                service.speak(T("Kata pemicu ini sudah dipakai oleh macro lain. Gunakan kata lain.", "This trigger word is already used by another macro. Use a different word."))
                khusus.showMacroForm(index, values)
                return
            end
        end
        if index ~= nil then
            list[index] = { trigger = newTrigger, content = newContent }
            service.speak(T("Macro diperbarui.", "Macro updated."))
        else
            list[#list + 1] = { trigger = newTrigger, content = newContent }
            service.speak(T("Macro ditambahkan.", "Macro added."))
        end
        khusus.saveMacros()
        khusus.showMacroMenu()
    end, function()
        khusus.showMacroMenu()
    end)
end

function khusus.showMacroDetail(index)
    local list = khusus.getMacros()
    local item = list[index]
    if item == nil then
        khusus.showMacroMenu()
        return
    end
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Macro ", "Macro ") .. index)
    builder.setMessage(T("Pemicu: ", "Trigger: ") .. item.trigger .. T("\nIsi: ", "\nContent: ") .. item.content)
    builder.setPositiveButton(T("Ubah", "Edit"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            khusus.showMacroForm(index, nil)
        end
    })
    builder.setNeutralButton(T("Hapus", "Delete"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            table.remove(list, index)
            khusus.saveMacros()
            service.speak(T("Macro dihapus.", "Macro deleted."))
            khusus.showMacroList()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            khusus.showMacroList()
        end
    })
    presentDialog(builder)
end

function khusus.showMacroList()
    local list = khusus.getMacros()
    if #list == 0 then
        service.speak(T("Belum ada macro tersimpan.", "No macros saved yet."))
        khusus.showMacroMenu()
        return
    end
    local items = {}
    for i, item in ipairs(list) do
        items[i] = i .. ". " .. item.trigger .. ": " .. khusus.preview(item.content, 40)
    end
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Daftar macro tersimpan (", "Saved macro list (") .. #list .. "/" .. khusus.maxMacro .. ")")
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which + 1 <= #list then
                khusus.showMacroDetail(which + 1)
            else
                khusus.showMacroMenu()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showMacroMenu()
    local list = khusus.getMacros()
    local items = {
        T("Tambah macro", "Add macro"),
        T("Daftar macro tersimpan (", "Saved macro list (") .. #list .. "/" .. khusus.maxMacro .. ")",
        T("Hapus semua macro", "Delete all macros"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Pengaturan macro", "Macro settings"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which == 0 then
                khusus.showMacroForm(nil, nil)
            elseif which == 1 then
                khusus.showMacroList()
            elseif which == 2 then
                khusus.showConfirm(T("Hapus semua macro", "Delete all macros"), T("Hapus semua macro yang tersimpan? Tindakan ini tidak bisa dibatalkan.", "Delete all saved macros? This action cannot be undone."), function()
                    khusus.macros = {}
                    khusus.saveMacros()
                    service.speak(T("Semua macro dihapus.", "All macros deleted."))
                    khusus.showMacroMenu()
                end, function()
                    khusus.showMacroMenu()
                end)
            else
                showKhususSettings()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showWordForm(index, prefill)
    local list = khusus.getWords()
    local current = nil
    if index ~= nil then
        current = list[index]
    end
    local origin = ""
    local replacement = ""
    local isRegex = false
    if prefill ~= nil then
        origin = prefill[1]
        replacement = prefill[2]
        isRegex = prefill.regex == true
    elseif current ~= nil then
        origin = current.origin
        replacement = current.replacement
        isRegex = current.isRegex == true
    end
    local title = T("Tambah kata kamus", "Add dictionary word")
    if index ~= nil then
        title = T("Ubah kata kamus", "Edit dictionary word")
    end
    khusus.showForm(title, {
        { hint = T("Kata asli", "Original word"), text = origin },
        { hint = T("Kata pengganti", "Replacement word"), text = replacement }
    }, T("Gunakan ekspresi reguler (Lua pattern)", "Use regular expression (Lua pattern)"), isRegex, T("Simpan", "Save"), function(values, checked)
        local newOrigin = khusus.trim(values[1])
        local newReplacement = tostring(values[2]):gsub("[\r\n]+", " ")
        newReplacement = khusus.trim(newReplacement)
        local keep = { values[1], values[2], regex = checked }
        if newOrigin == "" then
            service.speak(T("Kata asli tidak boleh kosong.", "The original word must not be empty."))
            khusus.showWordForm(index, keep)
            return
        end
        if checked and not khusus.validPattern(newOrigin) then
            service.speak(T("Pola regex tidak valid, periksa kembali sintaksnya.", "The regex pattern is not valid. Check its syntax again."))
            khusus.showWordForm(index, keep)
            return
        end
        newOrigin = newOrigin:gsub("[\r\n]+", " ")
        local entry = { origin = newOrigin, replacement = newReplacement, isRegex = checked }
        if index ~= nil then
            list[index] = entry
            service.speak(T("Kamus diperbarui.", "Dictionary updated."))
        else
            list[#list + 1] = entry
            service.speak(T("Kamus disimpan.", "Dictionary saved."))
        end
        khusus.saveWords()
        khusus.showWordMenu()
    end, function()
        khusus.showWordMenu()
    end)
end

function khusus.showWordDetail(index)
    local list = khusus.getWords()
    local item = list[index]
    if item == nil then
        khusus.showWordMenu()
        return
    end
    local regexText = T("Tidak", "No")
    if item.isRegex then
        regexText = T("Ya", "Yes")
    end
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Kamus ", "Dictionary ") .. index)
    builder.setMessage(T("Asli: ", "Original: ") .. item.origin .. T("\nGanti: ", "\nReplace: ") .. item.replacement .. T("\nRegex: ", "\nRegex: ") .. regexText)
    builder.setPositiveButton(T("Ubah", "Edit"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            khusus.showWordForm(index, nil)
        end
    })
    builder.setNeutralButton(T("Hapus", "Delete"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            table.remove(list, index)
            khusus.saveWords()
            service.speak(T("Aturan kamus dihapus.", "Dictionary rule deleted."))
            khusus.showWordList()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            khusus.showWordList()
        end
    })
    presentDialog(builder)
end

function khusus.showWordList()
    local list = khusus.getWords()
    if #list == 0 then
        service.speak(T("Kamus kosong.", "The dictionary is empty."))
        khusus.showWordMenu()
        return
    end
    local items = {}
    for i, item in ipairs(list) do
        local tag = ""
        if item.isRegex then
            tag = "[REGEX] "
        end
        items[i] = i .. ". " .. tag .. khusus.preview(item.origin, 30) .. " -> " .. khusus.preview(item.replacement, 30)
    end
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Daftar kamus (", "Dictionary list (") .. #list .. ")")
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which + 1 <= #list then
                khusus.showWordDetail(which + 1)
            else
                khusus.showWordMenu()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showWordJson(prefill)
    if not khusus.json then
        service.speak(T("Fitur format JSON tidak tersedia di perangkat ini.", "The JSON format feature is not available on this device."))
        khusus.showWordMenu()
        return
    end
    local text = prefill
    if text == nil then
        local data = {}
        for i, item in ipairs(khusus.getWords()) do
            data[i] = { origin = item.origin, replacement = item.replacement, isRegex = item.isRegex == true }
        end
        text = khusus.json.encode(data)
    end
    khusus.showForm(T("Edit format JSON kamus", "Edit dictionary JSON format"), {
        { hint = T("Format JSON kamus", "Dictionary JSON format"), text = text, multiline = true }
    }, nil, nil, T("Simpan perubahan", "Save changes"), function(values)
        local ok, decoded = pcall(khusus.json.decode, values[1])
        if not ok or type(decoded) ~= "table" then
            service.speak(T("Format salah. Pastikan format JSON benar.", "Wrong format. Make sure the JSON format is correct."))
            khusus.showWordJson(values[1])
            return
        end
        local rebuilt = {}
        for _, item in ipairs(decoded) do
            if type(item) ~= "table" or type(item.origin) ~= "string" or khusus.trim(item.origin) == "" then
                service.speak(T("Format salah. Setiap aturan harus memiliki kata asli.", "Wrong format. Every rule must have an original word."))
                khusus.showWordJson(values[1])
                return
            end
            local isRegex = item.isRegex == true
            if isRegex and not khusus.validPattern(item.origin) then
                service.speak(T("Pola regex tidak valid, periksa kembali sintaksnya.", "The regex pattern is not valid. Check its syntax again."))
                khusus.showWordJson(values[1])
                return
            end
            rebuilt[#rebuilt + 1] = {
                origin = khusus.trim(item.origin),
                replacement = tostring(item.replacement or ""),
                isRegex = isRegex
            }
        end
        khusus.words = rebuilt
        khusus.saveWords()
        service.speak(T("Kamus diperbarui.", "Dictionary updated."))
        khusus.showWordMenu()
    end, function()
        khusus.showWordMenu()
    end)
end

function khusus.showWordMenu()
    local list = khusus.getWords()
    local items = {
        T("Tambah kata kamus", "Add dictionary word"),
        T("Daftar kamus (", "Dictionary list (") .. #list .. ")",
        T("Edit format JSON", "Edit JSON format"),
        T("Hapus semua kamus", "Delete all dictionaries"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Manajemen kamus", "Dictionary management"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which == 0 then
                khusus.showWordForm(nil, nil)
            elseif which == 1 then
                khusus.showWordList()
            elseif which == 2 then
                khusus.showWordJson(nil)
            elseif which == 3 then
                khusus.showConfirm(T("Hapus semua kamus", "Delete all dictionaries"), T("Hapus semua aturan kamus yang tersimpan? Tindakan ini tidak bisa dibatalkan.", "Delete all saved dictionary rules? This action cannot be undone."), function()
                    khusus.words = {}
                    khusus.saveWords()
                    service.speak(T("Semua kamus dihapus.", "All dictionaries deleted."))
                    khusus.showWordMenu()
                end, function()
                    khusus.showWordMenu()
                end)
            else
                showKhususSettings()
            end
        end
    })
    presentDialog(builder)
end

function khusus.applyToFocused()
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        service.speak(T("Tidak ada teks yang fokus.", "No text is focused."))
        return
    end
    local readable, current = pcall(function()
        return tostring(node.getText() or "")
    end)
    if not readable or current == "" then
        service.speak(T("Kotak teks kosong.", "The text box is empty."))
        return
    end
    local applied, newText = pcall(khusus.applyDictionary, current, true)
    if not applied then
        service.speak(T("Gagal menerapkan kamus, periksa entri kamus.", "Failed to apply the dictionary. Check the dictionary entries."))
        return
    end
    if newText == current then
        service.speak(T("Tidak ada kata yang diubah.", "No words were changed."))
        return
    end
    local written = pcall(function()
        local bundle = Bundle()
        bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, newText)
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
    end)
    if written then
        service.speak(T("Kamus diterapkan pada teks.", "Dictionary applied to the text."))
    else
        service.speak(T("Gagal menerapkan kamus pada teks.", "Failed to apply the dictionary to the text."))
    end
end

function khusus.matchDelete(list)
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        local mode = khusus.deleteTriggers[spoken]
        if mode ~= nil then
            return mode
        end
    end
    return nil
end

function khusus.matchUndo(list)
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        if khusus.undoTriggers[spoken] == true then
            return true
        end
    end
    return false
end

function khusus.deleteInFocused(mode)
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        return T("Tidak ada teks yang fokus.", "No text is focused.")
    end
    local hinted = false
    pcall(function()
        hinted = node.isShowingHintText() == true
    end)
    local readable, current = pcall(function()
        return tostring(node.getText() or "")
    end)
    if not readable or hinted or current == "" then
        return T("Kotak teks kosong.", "The text box is empty.")
    end
    local remaining = ""
    if mode == "part" then
        local last = khusus.lastInserted
        if last ~= nil and last ~= "" and #current >= #last and current:sub(-#last) == last then
            remaining = current:sub(1, #current - #last)
        else
            local trimmed = current:gsub("%s+$", "")
            remaining = trimmed:gsub("%S+$", "")
        end
    end
    if remaining == current then
        return T("Tidak ada yang dihapus.", "Nothing was deleted.")
    end
    local written = pcall(function()
        local bundle = Bundle()
        bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, remaining)
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
    end)
    if not written then
        return T("Teks gagal dihapus.", "The text could not be deleted.")
    end
    khusus.undoState = { before = current, after = remaining, time = SystemClock.elapsedRealtime() }
    khusus.lastInserted = nil
    if mode == "all" then
        return T("Semua teks dihapus.", "All text deleted.")
    end
    return T("Sebagian teks dihapus.", "Part of the text deleted.")
end

function khusus.undoDelete()
    local state = khusus.undoState
    if state == nil or SystemClock.elapsedRealtime() - state.time > khusus.undoWindowMs then
        khusus.undoState = nil
        return T("Tidak ada hapusan yang bisa dibatalkan.", "There is no deletion to undo.")
    end
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        return T("Tidak ada teks yang fokus.", "No text is focused.")
    end
    local hinted = false
    pcall(function()
        hinted = node.isShowingHintText() == true
    end)
    local readable, current = pcall(function()
        return tostring(node.getText() or "")
    end)
    if not readable then
        return T("Teks gagal dibaca.", "The text could not be read.")
    end
    if hinted then
        current = ""
    end
    if current ~= state.after then
        khusus.undoState = nil
        return T("Teks sudah berubah, hapusan tidak bisa dibatalkan.", "The text has changed, so the deletion cannot be undone.")
    end
    local written = pcall(function()
        local bundle = Bundle()
        bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, state.before)
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
    end)
    if not written then
        return T("Hapusan gagal dibatalkan.", "The deletion could not be undone.")
    end
    khusus.undoState = nil
    khusus.lastInserted = nil
    return T("Hapusan dibatalkan.", "Deletion undone.")
end

khusus.cleanTriggers = pickLogic({
    ["hapus sampah"] = true,
    ["hapus cache"] = true,
    ["hapus cache dan sampah"] = true
}, {
    ["clear junk"] = true,
    ["clear cache"] = true,
    ["clear cache and junk"] = true
})

function khusus.matchClean(list)
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        if khusus.cleanTriggers[spoken] == true then
            return true
        end
    end
    return false
end

khusus.autoTypeActiveKey = "ngetik_otomatis_aktif"
khusus.autoTypeBeatKey = "ngetik_otomatis_detak"
khusus.autoTypeTokenKey = "ngetik_otomatis_token"
khusus.autoTypeStaleMs = 30000
khusus.autoTypeTickMs = 300
khusus.autoTypeIdleMs = 450
khusus.autoTypeBeatEveryMs = 3000
khusus.autoTypeHold = 0
khusus.autoTypeToken = nil
khusus.autoTypeIdleSince = nil
khusus.autoTypeBeatAt = nil

khusus.autoTypeStartTriggers = pickLogic({
    ["tulisan otomatis"] = true,
    ["ngetik otomatis"] = true,
    ["mengetik otomatis"] = true
}, {
    ["auto typing"] = true,
    ["automatic typing"] = true
})

khusus.autoTypeStopTriggers = pickLogic({
    ["hentikan ngetik otomatis"] = true,
    ["hentikan mengetik otomatis"] = true,
    ["hentikan tulisan otomatis"] = true
}, {
    ["stop auto typing"] = true,
    ["stop automatic typing"] = true
})

function khusus.matchAutoType(list)
    if list == nil then
        return nil
    end
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        if khusus.autoTypeStopTriggers[spoken] == true then
            return "stop"
        end
        if khusus.autoTypeStartTriggers[spoken] == true then
            return "start"
        end
    end
    return nil
end

function khusus.autoTypeStored()
    local active = false
    local beat = 0
    local token = ""
    pcall(function()
        local prefs = getPrefs()
        active = prefs.getBoolean(khusus.autoTypeActiveKey, false) == true
        beat = tonumber(tostring(prefs.getString(khusus.autoTypeBeatKey, "0"))) or 0
        token = tostring(prefs.getString(khusus.autoTypeTokenKey, ""))
    end)
    return active, beat, token
end

function khusus.autoTypeOwns(token)
    if token == nil then
        return false
    end
    local active, beat, stored = khusus.autoTypeStored()
    return active and stored == token
end

function khusus.autoTypeRunning()
    return khusus.autoTypeOwns(khusus.autoTypeToken)
end

function khusus.autoTypeStop()
    khusus.autoTypeToken = nil
    khusus.autoTypeIdleSince = nil
    pcall(function()
        local editor = getPrefs().edit()
        editor.putBoolean(khusus.autoTypeActiveKey, false)
        editor.apply()
    end)
end

function khusus.autoTypeFail()
    if khusus.autoTypeRunning() then
        khusus.autoTypeStop()
    end
end

function khusus.autoTypeBeat(now)
    if khusus.autoTypeBeatAt ~= nil and now - khusus.autoTypeBeatAt < khusus.autoTypeBeatEveryMs then
        return
    end
    khusus.autoTypeBeatAt = now
    pcall(function()
        local editor = getPrefs().edit()
        editor.putString(khusus.autoTypeBeatKey, tostring(now))
        editor.apply()
    end)
end

function khusus.matchTranslateText(list)
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        local rest = spoken:match("^" .. khusus.translateTextWord .. "%s+(.+)$")
        if rest ~= nil then
            local stripping = true
            while stripping do
                stripping = false
                for _, filler in ipairs(khusus.translateTextFillers) do
                    local stripped = rest:match("^" .. filler .. "%s+(.+)$")
                    if stripped ~= nil then
                        rest = stripped
                        stripping = true
                    end
                end
            end
            local code = khusus.translateTextTriggers[rest]
            if code ~= nil then
                return code
            end
        end
    end
    return nil
end

function khusus.translateFocused(target)
    local say = khusus.speakAfterMicrophone
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        say(T("Tidak ada teks yang fokus.", "No text is focused."))
        return
    end
    local hinted = false
    pcall(function()
        hinted = node.isShowingHintText() == true
    end)
    local readable, current = pcall(function()
        return tostring(node.getText() or "")
    end)
    if not readable or hinted or khusus.trim(current) == "" then
        say(T("Kotak teks kosong.", "The text box is empty."))
        return
    end
    say(T("Menerjemahkan isi kotak edit ke bahasa ", "Translating the edit box content to ") .. khusus.languageName(target) .. ".")
    khusus.translate(current, "auto", target, function(result)
        if result == nil or result == "" or result == current then
            return
        end
        local freshFound, freshNode = pcall(function()
            return service.getEditText()
        end)
        if not freshFound or freshNode == nil then
            say(T("Tidak ada teks yang fokus.", "No text is focused."))
            return
        end
        local latestReadable, latest = pcall(function()
            return tostring(freshNode.getText() or "")
        end)
        if not latestReadable or latest ~= current then
            say(T("Teks berubah, terjemahan dibatalkan.", "The text changed, so the translation was cancelled."))
            return
        end
        local written = pcall(function()
            local bundle = Bundle()
            bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, result)
            freshNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
        end)
        if written then
            khusus.lastInserted = nil
            say(T("Tulisan telah diterjemahkan.", "The text has been translated."))
        else
            say(T("Tulisan gagal diganti dengan terjemahan.", "The text could not be replaced with the translation."))
        end
    end, true)
end

function khusus.collectNodeText(node, depth, parts)
    if node == nil or depth > 6 or #parts >= 40 then
        return
    end
    local visible = true
    local hidden = false
    pcall(function()
        visible = node.isVisibleToUser() ~= false
        hidden = node.isPassword() == true
    end)
    if not visible or hidden then
        return
    end
    local piece = ""
    pcall(function()
        local text = node.getText()
        if text ~= nil then
            piece = tostring(text)
        end
        if khusus.trim(piece) == "" then
            local description = node.getContentDescription()
            if description ~= nil then
                piece = tostring(description)
            end
        end
    end)
    piece = khusus.trim(piece)
    if piece ~= "" then
        parts[#parts + 1] = piece
        return
    end
    local count = 0
    pcall(function()
        count = node.getChildCount()
    end)
    for index = 0, count - 1 do
        local child = nil
        pcall(function()
            child = node.getChild(index)
        end)
        khusus.collectNodeText(child, depth + 1, parts)
    end
end

function khusus.readingFocus()
    local found, focus = pcall(function()
        local roots = {}
        local active = service.getRootInActiveWindow()
        if active ~= nil then
            roots[#roots + 1] = active
        end
        pcall(function()
            local windows = service.getWindows()
            for index = 0, windows.size() - 1 do
                local window = windows.get(index)
                if window.getType() ~= 2 then
                    local root = window.getRoot()
                    if root ~= nil then
                        roots[#roots + 1] = root
                    end
                end
            end
        end)
        for _, root in ipairs(roots) do
            local node = root.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)
            if node ~= nil then
                return node
            end
        end
        for _, root in ipairs(roots) do
            local node = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if node ~= nil then
                return node
            end
        end
        return nil
    end)
    if found then
        return focus
    end
    return nil
end

function khusus.isEditNode(node)
    local editable = false
    pcall(function()
        editable = node.isEditable() == true
        if not editable then
            editable = tostring(node.getClassName()):find("EditText", 1, true) ~= nil
        end
    end)
    return editable
end

function khusus.translateOutside(target, node)
    local say = khusus.speakAfterMicrophone
    local parts = {}
    khusus.collectNodeText(node, 0, parts)
    local original = khusus.trim(table.concat(parts, "\n"))
    if original == "" then
        say(T("Tidak ada teks pada item yang fokus.", "There is no text on the focused item."))
        return
    end
    say(T("Menerjemahkan item yang fokus ke bahasa ", "Translating the focused item to ") .. khusus.languageName(target) .. ".")
    khusus.translate(original, "auto", target, function(result)
        if result == nil or result == "" or result == original then
            return
        end
        say(result)
    end, true)
end

function khusus.translateByFocus(target)
    local focus = khusus.entryFocus
    khusus.entryFocus = nil
    if focus ~= nil and not khusus.isEditNode(focus) then
        khusus.translateOutside(target, focus)
        return
    end
    khusus.translateFocused(target)
end

function khusus.showLanguageChoice(isSource)
    local names = {}
    local current
    local title
    if isSource then
        names[1] = T("Deteksi otomatis", "Auto detect")
        for i, item in ipairs(khusus.languages) do
            names[i + 1] = item.name
        end
        current = khusus.languageIndex(khusus.sourceLang(), true)
        title = T("Bahasa asal", "Source language")
    else
        for i, item in ipairs(khusus.languages) do
            names[i] = item.name
        end
        current = khusus.languageIndex(khusus.targetLang(), false)
        title = T("Bahasa tujuan", "Target language")
    end
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setSingleChoiceItems(names, current - 1, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            if isSource then
                if which == 0 then
                    getPrefs().edit().putString("terjemah_asal", "auto").apply()
                else
                    getPrefs().edit().putString("terjemah_asal", khusus.languages[which].code).apply()
                end
            else
                getPrefs().edit().putString("terjemah_tujuan", khusus.languages[which + 1].code).apply()
            end
            dialog.dismiss()
            khusus.showTranslateMenu()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            khusus.showTranslateMenu()
        end
    })
    presentDialog(builder)
end

function khusus.showTranslateMenu()
    local items = {
        T("Bahasa asal: ", "Source language: ") .. khusus.languageName(khusus.sourceLang()),
        T("Bahasa tujuan: ", "Target language: ") .. khusus.languageName(khusus.targetLang()),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Pilih bahasa terjemahan", "Choose translation language"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which == 0 then
                khusus.showLanguageChoice(true)
            elseif which == 1 then
                khusus.showLanguageChoice(false)
            else
                showKhususSettings()
            end
        end
    })
    presentDialog(builder)
end

khusus.correctionKeyUrl = "https://console.groq.com/keys"
khusus.correctionApi = "https://api.groq.com/openai/v1"
khusus.correctionDefaultModel = "llama-3.3-70b-versatile"
khusus.correctionDraft = nil
khusus.correctionTriggers = pickLogic({
    ["koreksi tulisan"] = true,
    ["koreksi teks"] = true,
    ["koreksi tulisan ini"] = true
}, {
    ["correct text"] = true,
    ["correct writing"] = true,
    ["proofread text"] = true
})
khusus.correctionExcludedModels = { "whisper", "tts", "guard", "orpheus", "embed" }

function khusus.correctionKey()
    return khusus.trim(getPrefs().getString("koreksi_kunci", ""))
end

function khusus.correctionModel()
    local model = khusus.trim(getPrefs().getString("koreksi_model", ""))
    if model == "" then
        return khusus.correctionDefaultModel
    end
    return model
end

function khusus.correctionInstruction()
    local text = khusus.trim(getPrefs().getString("koreksi_instruksi", ""))
    if text == "" then
        return pickLogic("Koreksi ejaan, tanda baca, huruf kapital, dan tata bahasa tanpa mengubah maksud dan gaya penulisan.", "Correct spelling, punctuation, capitalization, and grammar without changing the meaning or writing style.")
    end
    return text
end

function khusus.correctionModelList()
    local list = {}
    local raw = tostring(getPrefs().getString("koreksi_model_daftar", ""))
    for line in raw:gmatch("[^\n]+") do
        list[#list + 1] = line
    end
    return list
end

function khusus.matchCorrect(list)
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        if khusus.correctionTriggers[spoken] == true then
            return true
        end
    end
    return false
end

function khusus.jsonQuote(value)
    local escapes = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t", ["\b"] = "\\b", ["\f"] = "\\f" }
    local escaped = tostring(value):gsub('[%c"\\]', function(char)
        return escapes[char] or string.format("\\u%04x", char:byte())
    end)
    return '"' .. escaped .. '"'
end

function khusus.utf8Char(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    elseif code < 0x10000 then
        return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
    end
    return string.char(0xF0 + math.floor(code / 0x40000), 0x80 + math.floor(code / 0x1000) % 0x40, 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

function khusus.jsonField(raw, name)
    local _, stop = tostring(raw):find('"' .. name .. '"%s*:%s*"')
    if stop == nil then
        return nil
    end
    local simple = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
    local pieces = {}
    local index = stop + 1
    local length = #raw
    while index <= length do
        local char = raw:sub(index, index)
        if char == '"' then
            return table.concat(pieces)
        elseif char == "\\" then
            local following = raw:sub(index + 1, index + 1)
            if following == "u" then
                local code = tonumber(raw:sub(index + 2, index + 5), 16) or 63
                index = index + 6
                if code >= 0xD800 and code <= 0xDBFF and raw:sub(index, index + 1) == "\\u" then
                    local low = tonumber(raw:sub(index + 2, index + 5), 16)
                    if low ~= nil and low >= 0xDC00 and low <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                        index = index + 6
                    end
                end
                pieces[#pieces + 1] = khusus.utf8Char(code)
            else
                pieces[#pieces + 1] = simple[following] or following
                index = index + 2
            end
        else
            pieces[#pieces + 1] = char
            index = index + 1
        end
    end
    return nil
end

function khusus.groqRequest(method, path, key, body)
    if khusus.offlineOnly() then
        return -1, ""
    end
    local conn, reader, writer
    local ok, status, text = pcall(function()
        conn = URL(khusus.correctionApi .. path).openConnection()
        conn.setRequestMethod(method)
        conn.setRequestProperty("Authorization", "Bearer " .. key)
        conn.setRequestProperty("Accept", "application/json")
        conn.setRequestProperty("User-Agent", khusus.userAgent)
        conn.setConnectTimeout(15000)
        conn.setReadTimeout(90000)
        if body ~= nil then
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.setDoOutput(true)
            writer = OutputStreamWriter(conn.getOutputStream(), "UTF-8")
            writer.write(body)
            writer.flush()
        end
        local code = tonumber(conn.getResponseCode()) or -1
        local stream = (code >= 200 and code < 300) and conn.getInputStream() or conn.getErrorStream()
        local content = ""
        if stream then
            reader = BufferedReader(InputStreamReader(stream, "UTF-8"))
            local builder = StringBuilder()
            local line = reader.readLine()
            while line ~= nil do
                builder.append(line)
                line = reader.readLine()
            end
            content = tostring(builder.toString())
        end
        return code, content
    end)
    pcall(function() if writer then writer.close() end end)
    pcall(function() if reader then reader.close() end end)
    pcall(function() if conn then conn.disconnect() end end)
    if not ok then
        return -1, tostring(status)
    end
    return status, text
end

function khusus.groqError(status, text)
    if khusus.offlineOnly() then
        return khusus.offlineMessage()
    end
    if status == -1 then
        return T("Tidak ada koneksi ke server Groq.", "Could not connect to the Groq server.")
    elseif status == 401 then
        return T("Kunci API ditolak. Periksa kunci di menu Koreksi tulisan.", "The API key was rejected. Check the key in the Text correction menu.")
    elseif status == 429 then
        return T("Batas pemakaian Groq tercapai. Coba lagi nanti.", "The Groq usage limit was reached. Try again later.")
    end
    local detail = khusus.jsonField(text, "message")
    if detail ~= nil and detail ~= "" then
        return "HTTP " .. tostring(status) .. ": " .. detail
    end
    return "HTTP " .. tostring(status)
end

function khusus.refreshModels(key, callback)
    Thread(function()
        local ok, status, text = pcall(khusus.groqRequest, "GET", "/models", key, nil)
        khusus.handler.post(function()
            if not ok then
                callback(nil, tostring(status))
                return
            end
            if status ~= 200 then
                callback(nil, khusus.groqError(status, text))
                return
            end
            local models = {}
            local seen = {}
            for id in tostring(text):gmatch('"id"%s*:%s*"([^"]+)"') do
                local allowed = not seen[id]
                local lowered = id:lower()
                for _, word in ipairs(khusus.correctionExcludedModels) do
                    if lowered:find(word, 1, true) ~= nil then
                        allowed = false
                    end
                end
                if allowed then
                    seen[id] = true
                    models[#models + 1] = id
                end
            end
            table.sort(models)
            if #models == 0 then
                callback(nil, T("Daftar model kosong.", "The model list is empty."))
                return
            end
            callback(models, nil)
        end)
    end).start()
end

function khusus.correctText(text, callback)
    local system = pickLogic("Kamu adalah mesin pemroses tulisan. Pesan pengguna berisi teks yang harus kamu proses, bukan pertanyaan untuk dijawab. Ikuti instruksi berikut dengan patuh dan lengkap: ", "You are a text processing engine. The user message contains text for you to process, not a question to answer. Follow the instruction below faithfully and completely: ")
        .. khusus.correctionInstruction()
        .. pickLogic("\n\nBalas hanya dengan hasil akhir teksnya, tanpa pembuka, penjelasan, atau tanda kutip tambahan.", "\n\nReply only with the final resulting text, without any preface, explanation, or extra quotation marks.")
    local body = '{"model":' .. khusus.jsonQuote(khusus.correctionModel())
        .. ',"temperature":0.3,"messages":[{"role":"system","content":' .. khusus.jsonQuote(system)
        .. '},{"role":"user","content":' .. khusus.jsonQuote(text) .. '}]}'
    local key = khusus.correctionKey()
    Thread(function()
        local ok, status, raw = pcall(khusus.groqRequest, "POST", "/chat/completions", key, body)
        khusus.handler.post(function()
            if not ok then
                callback(nil, tostring(status))
                return
            end
            if status ~= 200 then
                callback(nil, khusus.groqError(status, raw))
                return
            end
            local result = khusus.jsonField(raw, "content")
            if result ~= nil then
                result = khusus.trim((result:gsub("<think>.-</think>", "")))
            end
            if result == nil or result == "" then
                callback(nil, T("Server tidak mengembalikan hasil.", "The server returned no result."))
                return
            end
            callback(result, nil)
        end)
    end).start()
end

function khusus.correctFocused()
    local say = khusus.speakAfterMicrophone
    if khusus.offlineOnly() then
        say(khusus.offlineMessage())
        return
    end
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        say(T("Tidak ada teks yang fokus.", "No text is focused."))
        return
    end
    local hinted = false
    pcall(function()
        hinted = node.isShowingHintText() == true
    end)
    local readable, current = pcall(function()
        return tostring(node.getText() or "")
    end)
    if not readable or hinted or khusus.trim(current) == "" then
        say(T("Kotak teks kosong.", "The text box is empty."))
        return
    end
    if khusus.correctionKey() == "" then
        say(T("Kunci API belum diisi. Isi di Pengaturan khusus bjr, menu Koreksi tulisan.", "The API key is not set. Set it in Bjr special settings, Text correction menu."))
        return
    end
    say(T("Mengoreksi tulisan.", "Correcting the text."))
    khusus.correctText(current, function(result, reason)
        if result == nil then
            say(T("Koreksi tulisan gagal: ", "Text correction failed: ") .. tostring(reason))
            return
        end
        if result == current then
            say(T("Tidak ada yang perlu diubah.", "Nothing needed to change."))
            return
        end
        local freshFound, freshNode = pcall(function()
            return service.getEditText()
        end)
        if not freshFound or freshNode == nil then
            say(T("Tidak ada teks yang fokus.", "No text is focused."))
            return
        end
        local latestReadable, latest = pcall(function()
            return tostring(freshNode.getText() or "")
        end)
        if not latestReadable or latest ~= current then
            say(T("Teks berubah, koreksi dibatalkan.", "The text changed, so the correction was cancelled."))
            return
        end
        local written = pcall(function()
            local bundle = Bundle()
            bundle.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, result)
            freshNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
        end)
        if written then
            khusus.lastInserted = nil
            say(T("Tulisan telah dikoreksi.", "The text has been corrected."))
        else
            say(T("Tulisan gagal diganti dengan hasil koreksi.", "The text could not be replaced with the corrected result."))
        end
    end)
end

function khusus.correctByFocus()
    local focus = khusus.entryFocus
    khusus.entryFocus = nil
    if focus ~= nil and not khusus.isEditNode(focus) then
        khusus.speakAfterMicrophone(T("Koreksi tulisan hanya bekerja di dalam kotak edit.", "Text correction only works inside an edit box."))
        return
    end
    khusus.correctFocused()
end

function khusus.showCorrectionModelChoice(draft)
    local models = khusus.correctionModelList()
    local current = 0
    for index, name in ipairs(models) do
        if name == draft.model then
            current = index
        end
    end
    if current == 0 then
        table.insert(models, 1, draft.model)
        current = 1
    end
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Model AI", "AI model"))
    builder.setSingleChoiceItems(models, current - 1, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            draft.model = models[which + 1]
            khusus.correctionDraft = draft
            dialog.dismiss()
            khusus.showCorrectionMenu()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            khusus.correctionDraft = draft
            dialog.dismiss()
            khusus.showCorrectionMenu()
        end
    })
    presentDialog(builder)
end

function khusus.showCorrectionMenu()
    local draft = khusus.correctionDraft
    khusus.correctionDraft = nil
    if draft == nil then
        draft = {
            key = khusus.correctionKey(),
            instruction = khusus.trim(getPrefs().getString("koreksi_instruksi", "")),
            model = khusus.correctionModel()
        }
    end

    local layout = LinearLayout(this)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(48, 32, 48, 16)

    local getKeyButton = Button(this)
    getKeyButton.setText(T("Ambil kunci API", "Get API key"))
    layout.addView(getKeyButton)

    local keyField = EditText(this)
    keyField.setHint(T("Kunci API Groq", "Groq API key"))
    keyField.setContentDescription(T("Kunci API Groq", "Groq API key"))
    keyField.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS)
    keyField.setText(draft.key)
    layout.addView(keyField)

    local instructionField = EditText(this)
    local instructionHint = T("Instruksi custom. Kosong berarti koreksi ejaan dan tata bahasa", "Custom instruction. Empty means spelling and grammar correction")
    instructionField.setHint(instructionHint)
    instructionField.setContentDescription(instructionHint)
    instructionField.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_MULTI_LINE)
    instructionField.setMinLines(3)
    instructionField.setMaxLines(8)
    instructionField.setText(draft.instruction)
    layout.addView(instructionField)

    local modelButton = Button(this)
    modelButton.setText(T("Model AI: ", "AI model: ") .. draft.model)
    layout.addView(modelButton)

    local refreshButton = Button(this)
    refreshButton.setText(T("Refresh model AI", "Refresh AI models"))
    layout.addView(refreshButton)

    local scroll = ScrollView(this)
    scroll.addView(layout)

    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Koreksi tulisan", "Text correction"))
    builder.setView(scroll)

    local dialog = nil

    local function typedKey()
        return (tostring(keyField.getText()):gsub("%s+", ""))
    end

    local function capture()
        khusus.correctionDraft = {
            key = tostring(keyField.getText()),
            instruction = tostring(instructionField.getText()),
            model = draft.model
        }
    end

    getKeyButton.setOnClickListener(View.OnClickListener{
        onClick = function(view)
            feedbackUI()
            capture()
            if dialog ~= nil then
                dialog.dismiss()
            end
            local opened = pcall(function()
                local intent = Intent(Intent.ACTION_VIEW, Uri.parse(khusus.correctionKeyUrl))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                this.startActivity(intent)
            end)
            if opened then
                service.speak(T("Membuka browser untuk membuat kunci API Groq. Setelah kunci dibuat, salin, lalu buka lagi menu Koreksi tulisan dan tempel di kotak kunci API.", "Opening the browser to create a Groq API key. After the key is created, copy it, then open the Text correction menu again and paste it in the API key box."))
            else
                service.speak(T("Browser gagal dibuka.", "The browser could not be opened."))
            end
        end
    })

    modelButton.setOnClickListener(View.OnClickListener{
        onClick = function(view)
            feedbackUI()
            capture()
            local pending = khusus.correctionDraft
            khusus.correctionDraft = nil
            if dialog ~= nil then
                dialog.dismiss()
            end
            khusus.showCorrectionModelChoice(pending)
        end
    })

    refreshButton.setOnClickListener(View.OnClickListener{
        onClick = function(view)
            feedbackUI()
            local key = typedKey()
            if key == "" then
                key = khusus.correctionKey()
            end
            if key == "" then
                service.speak(T("Isi kunci API terlebih dahulu.", "Enter the API key first."))
                return
            end
            service.speak(T("Memperbarui daftar model AI.", "Refreshing the AI model list."))
            khusus.refreshModels(key, function(models, reason)
                if models == nil then
                    service.speak(T("Gagal memperbarui model: ", "Failed to refresh models: ") .. tostring(reason))
                    return
                end
                getPrefs().edit().putString("koreksi_model_daftar", table.concat(models, "\n")).apply()
                service.speak(T("Daftar model diperbarui. Jumlah model: ", "Model list refreshed. Number of models: ") .. tostring(#models) .. ".")
            end)
        end
    })

    builder.setPositiveButton(T("Simpan", "Save"), DialogInterface.OnClickListener{
        onClick = function(saveDialog, which)
            feedbackUI()
            local saved = pcall(function()
                getPrefs().edit()
                    .putString("koreksi_kunci", typedKey())
                    .putString("koreksi_instruksi", khusus.trim(tostring(instructionField.getText())))
                    .putString("koreksi_model", draft.model)
                    .apply()
            end)
            saveDialog.dismiss()
            if saved then
                service.speak(T("Pengaturan koreksi tulisan disimpan.", "Text correction settings saved."))
            else
                service.speak(T("Pengaturan koreksi tulisan gagal disimpan.", "Text correction settings could not be saved."))
            end
            showKhususSettings()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(backDialog, which)
            feedbackUI()
            backDialog.dismiss()
            showKhususSettings()
        end
    })
    dialog = presentDialog(builder)
end

showKhususSettings = function()
    profileLayer.values = nil
    if not khusus.pro.require() then
        return
    end
    local items = {
        T("Aktifkan kamus: ", "Enable dictionary: ") .. stateText(getFlag("kamus_aktif")),
        T("Manajemen kamus", "Dictionary management"),
        T("Terapkan kamus pada teks", "Apply dictionary to text"),
        T("Aktifkan/nonaktifkan makro: ", "Enable/disable macros: ") .. stateText(getFlag("makro_aktif")),
        T("Pengaturan macro", "Macro settings"),
        T("Terjemahkan output: ", "Translate output: ") .. stateText(getFlag("terjemah_output", false)),
        T("Pilih bahasa terjemahan", "Choose translation language"),
        T("Koreksi tulisan", "Text correction"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Pengaturan khusus bjr", "Bjr special settings"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            if which == 0 then
                toggleFlag("kamus_aktif")
                feedbackUI()
                showKhususSettings()
            elseif which == 1 then
                feedbackUI()
                khusus.showWordMenu()
            elseif which == 2 then
                feedbackUI()
                dialog.dismiss()
                khusus.applyToFocused()
            elseif which == 3 then
                toggleFlag("makro_aktif")
                feedbackUI()
                showKhususSettings()
            elseif which == 4 then
                feedbackUI()
                khusus.showMacroMenu()
            elseif which == 5 then
                toggleFlag("terjemah_output", false)
                feedbackUI()
                showKhususSettings()
            elseif which == 6 then
                feedbackUI()
                khusus.showTranslateMenu()
            elseif which == 7 then
                feedbackUI()
                khusus.showCorrectionMenu()
            else
                feedbackUI()
                dialog.dismiss()
                showMainSettings()
            end
        end
    })
    presentDialog(builder)
end

khusus.backupDir = "/storage/emulated/0/Download/"
khusus.backupName = "cadangan_pengaturan_bjr.txt"
khusus.backupHeader = "BJR_BACKUP_V1"
khusus.backupKeys = {
    { "b", "asisten_aktif" },
    { "b", "baris_baru" },
    { "b", "bersihkan_isian" },
    { "b", "ejaan_rapi" },
    { "b", "gaya_cadel" },
    { "b", "gaya_gagap" },
    { "b", "gaya_jaksel" },
    { "b", "gaya_singkatan" },
    { "b", "jeda_napas" },
    { "b", "kamus_aktif" },
    { "b", "kapital_otomatis" },
    { "b", "makro_aktif" },
    { "b", "offline_penuh" },
    { "b", "pengingat_dikte" },
    { "b", "profil_otomatis" },
    { "b", "spasi_setelah_teks" },
    { "b", "tanda_baca_otomatis" },
    { "b", "terjemah_output" },
    { "b", "ucapkan_hasil" },
    { "i", "bahasa" },
    { "i", "sensitivitas" },
    { "i", "getaran_mode" },
    { "i", "getaran_kekuatan" },
    { "i", "target_harian" },
    { "i", "koreksi_hijriah" },
    { "s", "makro_data" },
    { "s", "kamus_data" },
    { "s", "profil_data" },
    { "s", "profil_aplikasi" },
    { "s", "terjemah_asal" },
    { "s", "terjemah_tujuan" },
    { "s", "koreksi_instruksi" },
    { "s", "koreksi_model" }
}
khusus.backupKinds = {}
for _, spec in ipairs(khusus.backupKeys) do
    khusus.backupKinds[spec[2]] = spec[1]
end

function khusus.sdkInt()
    local ok, value = pcall(function()
        return luajava.bindClass("android.os.Build$VERSION").SDK_INT
    end)
    if ok and value ~= nil then
        return tonumber(value) or 0
    end
    return 0
end

function khusus.collectLines(reader)
    local collected = {}
    while true do
        local line = reader.readLine()
        if line == nil then
            break
        end
        collected[#collected + 1] = tostring(line)
    end
    reader.close()
    return collected
end

function khusus.mediaStoreFind(resolver, collection)
    local cursor = resolver.query(collection, { "_id" }, "_display_name=?", { khusus.backupName }, nil)
    if cursor == nil then
        return nil
    end
    local uri = nil
    pcall(function()
        if cursor.moveToFirst() then
            uri = luajava.bindClass("android.content.ContentUris").withAppendedId(collection, cursor.getLong(0))
        end
    end)
    cursor.close()
    return uri
end

function khusus.mediaStoreWrite(content)
    if khusus.sdkInt() < 29 then
        return false
    end
    local ok, saved = pcall(function()
        local resolver = this.getContentResolver()
        local collection = luajava.bindClass("android.provider.MediaStore$Downloads").EXTERNAL_CONTENT_URI
        local uri = khusus.mediaStoreFind(resolver, collection)
        if uri == nil then
            local values = luajava.newInstance("android.content.ContentValues")
            values.put("_display_name", khusus.backupName)
            values.put("mime_type", "text/plain")
            values.put("relative_path", "Download")
            uri = resolver.insert(collection, values)
        end
        if uri == nil then
            return false
        end
        local stream = resolver.openOutputStream(uri, "wt")
        if stream == nil then
            return false
        end
        local writer = BufferedWriter(OutputStreamWriter(stream, "UTF-8"))
        writer.write(content)
        writer.flush()
        writer.close()
        return true
    end)
    return ok and saved == true
end

function khusus.mediaStoreLines()
    if khusus.sdkInt() < 29 then
        return nil
    end
    local ok, lines = pcall(function()
        local resolver = this.getContentResolver()
        local collection = luajava.bindClass("android.provider.MediaStore$Downloads").EXTERNAL_CONTENT_URI
        local uri = khusus.mediaStoreFind(resolver, collection)
        if uri == nil then
            return nil
        end
        local stream = resolver.openInputStream(uri)
        if stream == nil then
            return nil
        end
        return khusus.collectLines(BufferedReader(InputStreamReader(stream, "UTF-8")))
    end)
    if ok then
        return lines
    end
    return nil
end

function khusus.writeBackup()
    local ok, result = pcall(function()
        khusus.getMacros()
        khusus.saveMacros()
        khusus.getWords()
        khusus.saveWords()
        local prefs = getPrefs()
        local lines = { khusus.backupHeader }
        local count = 0
        for _, spec in ipairs(khusus.backupKeys) do
            local kind = spec[1]
            local key = spec[2]
            if prefs.contains(key) then
                local value = ""
                if kind == "b" then
                    if prefs.getBoolean(key, false) then
                        value = "1"
                    else
                        value = "0"
                    end
                elseif kind == "i" then
                    value = tostring(math.floor(prefs.getInt(key, 0)))
                else
                    value = khusus.escape(prefs.getString(key, ""))
                end
                lines[#lines + 1] = kind .. "|" .. key .. "|" .. value
                count = count + 1
            end
        end
        lines[#lines + 1] = "END|" .. count
        local content = table.concat(lines, "\n") .. "\n"
        local saved = false
        pcall(function()
            local directory = File(khusus.backupDir)
            if not directory.exists() then
                directory.mkdirs()
            end
            local file = File(khusus.backupDir .. khusus.backupName)
            local writer = BufferedWriter(OutputStreamWriter(FileOutputStream(file), "UTF-8"))
            writer.write(content)
            writer.flush()
            writer.close()
            saved = file.exists() and file.length() > 0
        end)
        if not saved then
            saved = khusus.mediaStoreWrite(content)
        end
        return saved
    end)
    return ok and result == true
end

function khusus.readBackup()
    local ok, lines = pcall(function()
        local existed = false
        local fromFile = nil
        pcall(function()
            local file = File(khusus.backupDir .. khusus.backupName)
            if file.exists() then
                existed = true
                fromFile = khusus.collectLines(BufferedReader(InputStreamReader(FileInputStream(file), "UTF-8")))
            end
        end)
        if fromFile ~= nil then
            return fromFile
        end
        local fromStore = khusus.mediaStoreLines()
        if fromStore ~= nil then
            return fromStore
        end
        if existed then
            error("unreadable")
        end
        return nil
    end)
    if not ok then
        return nil, "invalid"
    end
    if lines == nil then
        return nil, "missing"
    end
    if #lines == 0 then
        return nil, "invalid"
    end
    local header = lines[1]:gsub("^\239\187\191", "")
    header = header:gsub("\r$", "")
    if header ~= khusus.backupHeader then
        return nil, "invalid"
    end
    local data = {}
    local count = 0
    local finished = false
    for i = 2, #lines do
        local line = lines[i]:gsub("\r$", "")
        if line ~= "" then
            if finished then
                return nil, "invalid"
            end
            local total = line:match("^END|(%d+)$")
            if total ~= nil then
                if tonumber(total) ~= count then
                    return nil, "invalid"
                end
                finished = true
            else
                local kind, key, value = line:match("^(%a)|([%w_]+)|(.*)$")
                if kind == nil then
                    return nil, "invalid"
                end
                local expected = khusus.backupKinds[key]
                if expected ~= nil then
                    if expected ~= kind then
                        return nil, "invalid"
                    end
                    if kind == "b" and value ~= "0" and value ~= "1" then
                        return nil, "invalid"
                    end
                    if kind == "i" and value:match("^%-?%d+$") == nil then
                        return nil, "invalid"
                    end
                    data[key] = value
                end
                count = count + 1
            end
        end
    end
    if not finished then
        return nil, "invalid"
    end
    return data
end

function khusus.applyBackup(data)
    local ok, committed = pcall(function()
        local editor = getPrefs().edit()
        for _, spec in ipairs(khusus.backupKeys) do
            local kind = spec[1]
            local key = spec[2]
            local value = data[key]
            if value == nil then
                editor.remove(key)
            elseif kind == "b" then
                editor.putBoolean(key, value == "1")
            elseif kind == "i" then
                editor.putInt(key, math.floor(tonumber(value)))
            else
                editor.putString(key, khusus.unescape(value))
            end
        end
        return editor.commit()
    end)
    khusus.macros = nil
    khusus.words = nil
    return ok and committed == true
end

function khusus.showNotice(title, message, onClose)
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setMessage(message)
    builder.setPositiveButton(T("Oke", "OK"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            onClose()
        end
    })
    presentDialog(builder)
end

function khusus.showOkCancel(title, message, onOk, onCancel)
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setMessage(message)
    builder.setPositiveButton(T("Oke", "OK"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            onOk()
        end
    })
    builder.setNegativeButton(T("Batal", "Cancel"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            onCancel()
        end
    })
    presentDialog(builder)
end

function khusus.confirmBackup()
    khusus.showOkCancel(T("Cadangkan pengaturan", "Back up settings"), T("Semua pengaturan, kamus, makro, dan terjemahan akan dicadangkan ke folder Download di penyimpanan internal. Tekan Oke untuk melanjutkan atau Batal.", "All settings, dictionaries, macros, and translations will be backed up to the Download folder in internal storage. Press OK to continue or Cancel."), function()
        if khusus.writeBackup() then
            khusus.showNotice(T("Cadangkan pengaturan", "Back up settings"), T("Pengaturan telah dicadangkan ke folder Download.", "Settings have been backed up to the Download folder."), khusus.showBackupMenu)
        else
            khusus.showNotice(T("Cadangkan pengaturan", "Back up settings"), T("Pengaturan gagal dicadangkan. Pastikan izin penyimpanan sudah diberikan.", "The settings could not be backed up. Make sure storage permission has been granted."), khusus.showBackupMenu)
        end
    end, khusus.showBackupMenu)
end

function khusus.confirmRestore()
    local data, reason = khusus.readBackup()
    if data == nil then
        local message = T("File cadangan tidak ditemukan di folder Download.", "The backup file was not found in the Download folder.")
        if reason == "invalid" then
            message = T("File cadangan rusak atau tidak dapat dibaca. Pengaturan tidak diubah.", "The backup file is damaged or cannot be read. Settings were not changed.")
        end
        khusus.showNotice(T("Kembalikan pengaturan", "Restore settings"), message, khusus.showBackupMenu)
        return
    end
    khusus.showOkCancel(T("Kembalikan pengaturan", "Restore settings"), T("Apakah anda akan mengembalikan pengaturan? Semua pengaturan, kamus, makro, dan terjemahan saat ini akan diganti dengan isi cadangan di folder Download. Tekan Oke atau Batal.", "Do you want to restore settings? All current settings, dictionaries, macros, and translations will be replaced with the backup in the Download folder. Press OK or Cancel."), function()
        if khusus.applyBackup(data) then
            khusus.showNotice(T("Kembalikan pengaturan", "Restore settings"), T("Pengaturan telah dikembalikan.", "Settings have been restored."), khusus.showBackupMenu)
        else
            khusus.showNotice(T("Kembalikan pengaturan", "Restore settings"), T("Pengaturan gagal dikembalikan.", "The settings could not be restored."), khusus.showBackupMenu)
        end
    end, khusus.showBackupMenu)
end

function khusus.cleanTemporary()
    local clean = true
    khusus.generation = khusus.generation + 1
    pcall(kill)
    pcall(function()
        khusus.handler.removeCallbacksAndMessages(nil)
    end)
    pcall(function()
        guideAudio.handler.removeCallbacksAndMessages(nil)
    end)
    pcall(stopGuideAudio)
    local macrosCleared = pcall(function()
        if khusus.macros ~= nil then
            khusus.saveMacros()
            khusus.macros = nil
        end
    end)
    local wordsCleared = pcall(function()
        if khusus.words ~= nil then
            khusus.saveWords()
            khusus.words = nil
        end
    end)
    if not macrosCleared or not wordsCleared then
        clean = false
    end
    khusus.quietRetries = 0
    khusus.lastDetected = nil
    khusus.lastAssistantTime = nil
    khusus.lastInserted = nil
    khusus.undoState = nil
    khusus.entryFocus = nil
    pcall(function()
        collectgarbage("collect")
    end)
    pcall(function()
        System.gc()
    end)
    return clean
end

function khusus.cleanByVoice()
    if khusus.cleanTemporary() then
        return T("Cache dan sampah telah dihapus.", "Cache and junk have been cleared.")
    end
    return T("Sebagian cache dan sampah gagal dihapus.", "Some cache and junk could not be cleared.")
end

function khusus.confirmClean()
    khusus.showOkCancel(T("Hapus cache dan sampah", "Clear cache and junk"), T("Sisa proses pengetikan yang tersimpan di memori alat akan dibersihkan, seperti pengenal suara yang tertinggal, antrean tunda, dan salinan sementara. Pengaturan, kamus, makro, terjemahan, dan file cadangan tidak dihapus. Tekan Oke untuk melanjutkan atau Batal.", "Leftovers from typing that are stored in the tool's memory will be cleared, such as lingering speech recognizers, delayed queues, and temporary copies. Settings, dictionaries, macros, translations, and backup files are not deleted. Press OK to continue or Cancel."), function()
        if khusus.cleanTemporary() then
            khusus.showNotice(T("Hapus cache dan sampah", "Clear cache and junk"), T("Cache dan sampah sisa proses pengetikan telah dihapus dari memori.", "Cache and typing leftovers have been cleared from memory."), khusus.showBackupMenu)
        else
            khusus.showNotice(T("Hapus cache dan sampah", "Clear cache and junk"), T("Sebagian cache dan sampah gagal dihapus. Pengaturan, kamus, makro, dan terjemahan tidak berubah.", "Some cache and junk could not be cleared. Settings, dictionaries, macros, and translations are unchanged."), khusus.showBackupMenu)
        end
    end, khusus.showBackupMenu)
end

function khusus.resetSettings()
    local ok, committed = pcall(function()
        local editor = getPrefs().edit()
        for _, spec in ipairs(khusus.backupKeys) do
            editor.remove(spec[2])
        end
        return editor.commit()
    end)
    khusus.macros = nil
    khusus.words = nil
    return ok and committed == true
end

function khusus.confirmReset()
    khusus.showOkCancel(T("Reset pengaturan yang tersimpan", "Reset saved settings"), T("Semua pengaturan, kamus, makro, dan terjemahan yang tersimpan akan dikembalikan ke bawaan awal. File cadangan di folder Download tidak dihapus. Tekan Oke untuk melanjutkan atau Batal.", "All saved settings, dictionary, macros, and translation will be returned to their defaults. The backup file in the Download folder is not deleted. Press OK to continue or Cancel."), function()
        if khusus.resetSettings() then
            khusus.showNotice(T("Reset pengaturan yang tersimpan", "Reset saved settings"), T("Pengaturan yang tersimpan telah direset.", "Saved settings have been reset."), khusus.showBackupMenu)
        else
            khusus.showNotice(T("Reset pengaturan yang tersimpan", "Reset saved settings"), T("Pengaturan gagal direset.", "The settings could not be reset."), khusus.showBackupMenu)
        end
    end, khusus.showBackupMenu)
end

function khusus.showBackupMenu()
    local items = {
        T("Cadangkan pengaturan", "Back up settings"),
        T("Kembalikan pengaturan", "Restore settings"),
        T("Hapus cache dan sampah", "Clear cache and junk"),
        T("Reset pengaturan yang tersimpan", "Reset saved settings"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Cadangkan dan kembalikan pengaturan Bjr", "Back up and restore Bjr settings"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which == 0 then
                khusus.confirmBackup()
            elseif which == 1 then
                khusus.confirmRestore()
            elseif which == 2 then
                khusus.confirmClean()
            elseif which == 3 then
                khusus.confirmReset()
            else
                showMainSettings()
            end
        end
    })
    presentDialog(builder)
end

khusus.maxProfile = 30
khusus.maxProfileName = 40

khusus.profileKeys = {
    { "kapital_otomatis", true, T("Huruf kapital otomatis", "Automatic capital letters") },
    { "baris_baru", true, T("Baris baru setelah teks", "New line after text") },
    { "tanda_baca_otomatis", false, T("Gunakan tanda baca otomatis", "Use automatic punctuation") },
    { "jeda_napas", true, T("Jeda napas jadi tanda baca", "Breath pause as punctuation") },
    { "spasi_setelah_teks", false, T("Spasi setelah teks", "Space after text") },
    { "gaya_singkatan", false, T("Gaya singkatan umum", "Common abbreviation style") },
    { "gaya_jaksel", false, T("Gunakan singkatan jaksel", "Use Jaksel abbreviations") },
    { "gaya_gagap", false, T("Gaya bicara gagap", "Stuttering speech style") },
    { "gaya_cadel", false, T("Gaya bicara cadel", "Lisping speech style") },
    { "ejaan_rapi", false, T("Ejaan rapi", "Neat spelling") },
    { "bersihkan_isian", true, T("Bersihkan kata isian dan pengulangan", "Remove filler words and repeats") }
}

khusus.profileKeySet = {}
for _, spec in ipairs(khusus.profileKeys) do
    khusus.profileKeySet[spec[1]] = true
end

khusus.builtinProfiles = {
    {
        id = "santai",
        name = T("Chat santai", "Casual chat"),
        values = {
            kapital_otomatis = false, baris_baru = false, tanda_baca_otomatis = false, jeda_napas = false,
            spasi_setelah_teks = true, gaya_singkatan = true, gaya_jaksel = false, gaya_gagap = false,
            gaya_cadel = false, ejaan_rapi = false
        }
    },
    {
        id = "formal",
        name = T("Formal", "Formal"),
        values = {
            kapital_otomatis = true, baris_baru = false, tanda_baca_otomatis = true, jeda_napas = true,
            spasi_setelah_teks = true, gaya_singkatan = false, gaya_jaksel = false, gaya_gagap = false,
            gaya_cadel = false, ejaan_rapi = false
        }
    },
    {
        id = "email",
        name = T("Surat/email", "Letter/email"),
        values = {
            kapital_otomatis = true, baris_baru = true, tanda_baca_otomatis = true, jeda_napas = true,
            spasi_setelah_teks = false, gaya_singkatan = false, gaya_jaksel = false, gaya_gagap = false,
            gaya_cadel = false, ejaan_rapi = false
        }
    }
}

khusus.defaultAssignments = {
    ["com.whatsapp"] = "santai",
    ["com.whatsapp.w4b"] = "santai",
    ["com.google.android.gm"] = "email"
}

function khusus.serializeProfileValues(values)
    local entries = {}
    for _, spec in ipairs(khusus.profileKeys) do
        local value = values[spec[1]]
        if value ~= nil then
            local flag = "0"
            if value then
                flag = "1"
            end
            entries[#entries + 1] = spec[1] .. ":" .. flag
        end
    end
    return table.concat(entries, ",")
end

function khusus.parseProfileValues(text)
    local values = {}
    for key, flag in tostring(text):gmatch("([%w_]+):([01])") do
        if khusus.profileKeySet[key] then
            values[key] = flag == "1"
        end
    end
    return values
end

function khusus.getCustomProfiles()
    local list = {}
    local raw = getPrefs().getString("profil_data", nil)
    if raw ~= nil then
        for line in tostring(raw):gmatch("[^\n]+") do
            local id, name, body = line:match("^([^|]*)|([^|]*)|(.*)$")
            if id ~= nil and id ~= "" then
                name = khusus.trim(khusus.unescape(name))
                if name ~= "" and #list < khusus.maxProfile then
                    list[#list + 1] = { id = id, name = name, values = khusus.parseProfileValues(body), custom = true }
                end
            end
        end
    end
    return list
end

function khusus.saveCustomProfiles(list)
    local lines = {}
    for _, item in ipairs(list) do
        lines[#lines + 1] = item.id .. "|" .. khusus.escape(item.name) .. "|" .. khusus.serializeProfileValues(item.values)
    end
    getPrefs().edit().putString("profil_data", table.concat(lines, "\n")).apply()
end

function khusus.allProfiles()
    local list = {}
    for _, item in ipairs(khusus.builtinProfiles) do
        list[#list + 1] = item
    end
    for _, item in ipairs(khusus.getCustomProfiles()) do
        list[#list + 1] = item
    end
    return list
end

function khusus.findProfile(id)
    if id == nil or id == "" then
        return nil
    end
    for _, item in ipairs(khusus.allProfiles()) do
        if item.id == id then
            return item
        end
    end
    return nil
end

function khusus.nextProfileId(list)
    local highest = 0
    for _, item in ipairs(list) do
        local number = tonumber(item.id:match("^u(%d+)$"))
        if number ~= nil and number > highest then
            highest = number
        end
    end
    return "u" .. (highest + 1)
end

function khusus.getAssignments()
    local map = {}
    for package, id in pairs(khusus.defaultAssignments) do
        map[package] = id
    end
    local raw = getPrefs().getString("profil_aplikasi", nil)
    if raw ~= nil then
        for line in tostring(raw):gmatch("[^\n]+") do
            local package, id = line:match("^([^|]+)|(.*)$")
            if package ~= nil then
                map[package] = id
            end
        end
    end
    return map
end

function khusus.saveAssignments(map)
    local packages = {}
    for package in pairs(map) do
        packages[#packages + 1] = package
    end
    table.sort(packages)
    local lines = {}
    for _, package in ipairs(packages) do
        lines[#lines + 1] = package .. "|" .. map[package]
    end
    getPrefs().edit().putString("profil_aplikasi", table.concat(lines, "\n")).apply()
end

function khusus.releaseAssignment(map, package)
    if khusus.defaultAssignments[package] ~= nil then
        map[package] = ""
    else
        map[package] = nil
    end
end

function khusus.profileLayerFor(editText)
    if not getFlag("profil_otomatis", false) then
        return nil
    end
    local package = nil
    pcall(function()
        local raw = editText.getPackageName()
        if raw ~= nil then
            package = tostring(raw)
        end
    end)
    if package == nil or package == "" then
        return nil
    end
    local profile = khusus.findProfile(khusus.getAssignments()[package])
    if profile == nil then
        return nil
    end
    return profile.values
end

function khusus.profileMatches(profile)
    local prefs = getPrefs()
    local compared = 0
    for _, spec in ipairs(khusus.profileKeys) do
        local value = profile.values[spec[1]]
        if value ~= nil then
            compared = compared + 1
            if prefs.getBoolean(spec[1], spec[2]) ~= value then
                return false
            end
        end
    end
    return compared > 0
end

function khusus.activeProfile()
    local list = khusus.allProfiles()
    local savedId = getPrefs().getString("profil_aktif", nil)
    if savedId ~= nil and savedId ~= "" then
        for _, item in ipairs(list) do
            if item.id == savedId then
                if khusus.profileMatches(item) then
                    return item
                end
                break
            end
        end
    end
    for _, item in ipairs(list) do
        if khusus.profileMatches(item) then
            return item
        end
    end
    return nil
end

function khusus.activeProfileText()
    local active = khusus.activeProfile()
    if active == nil then
        return T("pengaturan manual", "manual settings")
    end
    return active.name
end

function khusus.applyProfile(profile)
    local editor = getPrefs().edit()
    for key, value in pairs(profile.values) do
        editor.putBoolean(key, value)
    end
    editor.putString("profil_aktif", profile.id)
    editor.apply()
end

function khusus.describeProfile(profile)
    local lines = {}
    for _, spec in ipairs(khusus.profileKeys) do
        local value = profile.values[spec[1]]
        if value ~= nil then
            lines[#lines + 1] = spec[3] .. ": " .. stateText(value)
        end
    end
    return table.concat(lines, "\n")
end

function khusus.appLabel(package)
    local label = package
    pcall(function()
        local manager = this.getPackageManager()
        label = tostring(manager.getApplicationLabel(manager.getApplicationInfo(package, 0)))
    end)
    return label
end

function khusus.deleteProfile(id)
    local list = khusus.getCustomProfiles()
    for index, item in ipairs(list) do
        if item.id == id then
            table.remove(list, index)
            break
        end
    end
    khusus.saveCustomProfiles(list)
    local map = khusus.getAssignments()
    local changed = false
    for package, assigned in pairs(map) do
        if assigned == id then
            khusus.releaseAssignment(map, package)
            changed = true
        end
    end
    if changed then
        khusus.saveAssignments(map)
    end
end

function khusus.saveProfile(id, name, values)
    local list = khusus.getCustomProfiles()
    local function again()
        khusus.showProfileForm(id, { name = name, values = values })
    end
    if name == "" then
        service.speak(T("Nama profil tidak boleh kosong.", "The profile name must not be empty."))
        again()
        return
    end
    if #name > khusus.maxProfileName then
        service.speak(T("Nama profil terlalu panjang. Maksimal 40 karakter.", "The profile name is too long. The maximum is 40 characters."))
        again()
        return
    end
    local normalized = name:lower()
    for _, item in ipairs(khusus.allProfiles()) do
        if item.id ~= id and item.name:lower() == normalized then
            service.speak(T("Nama profil ini sudah dipakai. Gunakan nama lain.", "This profile name is already used. Use a different name."))
            again()
            return
        end
    end
    if id == nil then
        if #list >= khusus.maxProfile then
            service.speak(T("Batas maksimum 30 profil buatan sendiri tercapai.", "The maximum of 30 custom profiles has been reached."))
            khusus.showProfileMenu()
            return
        end
        local newId = khusus.nextProfileId(list)
        list[#list + 1] = { id = newId, name = name, values = values, custom = true }
        khusus.saveCustomProfiles(list)
        service.speak(T("Profil dibuat.", "Profile created."))
        khusus.showProfileDetail(newId)
        return
    end
    for index, item in ipairs(list) do
        if item.id == id then
            list[index] = { id = id, name = name, values = values, custom = true }
        end
    end
    khusus.saveCustomProfiles(list)
    service.speak(T("Profil diperbarui.", "Profile updated."))
    khusus.showProfileDetail(id)
end

function khusus.showProfileForm(id, prefill)
    local existing = nil
    if id ~= nil then
        existing = khusus.findProfile(id)
        if existing == nil or not existing.custom then
            khusus.showProfileList()
            return
        end
    end
    local nameText = ""
    local values = {}
    if prefill ~= nil then
        nameText = prefill.name
        values = prefill.values
    elseif existing ~= nil then
        nameText = existing.name
        values = existing.values
    end
    local layout = LinearLayout(this)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(48, 32, 48, 16)
    local field = EditText(this)
    local hint = T("Nama profil", "Profile name")
    field.setHint(hint)
    field.setContentDescription(hint)
    field.setText(nameText)
    layout.addView(field)
    local boxes = {}
    for index, spec in ipairs(khusus.profileKeys) do
        local box = CheckBox(this)
        box.setText(spec[3])
        local checked = values[spec[1]]
        if checked == nil then
            checked = getFlag(spec[1], spec[2])
        end
        box.setChecked(checked == true)
        layout.addView(box)
        boxes[index] = box
    end
    local scroll = ScrollView(this)
    scroll.addView(layout)
    local title = T("Buat profil baru", "Create new profile")
    if existing ~= nil then
        title = T("Ubah profil", "Edit profile")
    end
    local builder = AlertDialog.Builder(this)
    builder.setTitle(title)
    builder.setView(scroll)
    builder.setPositiveButton(T("Simpan", "Save"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            local newName = khusus.trim(tostring(field.getText()))
            local newValues = {}
            for index, spec in ipairs(khusus.profileKeys) do
                newValues[spec[1]] = boxes[index].isChecked()
            end
            dialog.dismiss()
            khusus.saveProfile(id, newName, newValues)
        end
    })
    builder.setNegativeButton(T("Batal", "Cancel"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if existing ~= nil then
                khusus.showProfileDetail(id)
            else
                khusus.showProfileMenu()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showAppPicker(id)
    local profile = khusus.findProfile(id)
    if profile == nil then
        khusus.showProfileList()
        return
    end
    local apps = {}
    local seen = {}
    for _, app in ipairs(khusus.loadApps()) do
        if not seen[app.pkg] then
            seen[app.pkg] = true
            apps[#apps + 1] = app
        end
    end
    if #apps == 0 then
        service.speak(T("Daftar aplikasi tidak terbaca di HP ini.", "The app list cannot be read on this phone."))
        khusus.showProfileDetail(id)
        return
    end
    table.sort(apps, function(first, second)
        return first.label:lower() < second.label:lower()
    end)
    local items = {}
    for index, app in ipairs(apps) do
        items[index] = app.label
    end
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Pasang profil ", "Assign profile ") .. profile.name .. T(" ke aplikasi", " to an app"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which + 1 <= #apps then
                local app = apps[which + 1]
                local map = khusus.getAssignments()
                map[app.pkg] = id
                khusus.saveAssignments(map)
                local message = T("Profil ", "Profile ") .. profile.name .. T(" dipasang ke ", " assigned to ") .. app.label .. "."
                if not getFlag("profil_otomatis", false) then
                    message = message .. T(" Aktifkan Profil otomatis per aplikasi agar berlaku.", " Turn on Automatic profile per app for it to take effect.")
                end
                service.speak(message)
            end
            khusus.showProfileDetail(id)
        end
    })
    presentDialog(builder)
end

function khusus.showAssignmentChoice(package)
    local profiles = khusus.allProfiles()
    local current = khusus.getAssignments()[package]
    local appName = khusus.appLabel(package)
    local items = {}
    for index, item in ipairs(profiles) do
        local label = item.name
        if item.id == current then
            label = label .. T(" (dipakai)", " (in use)")
        end
        items[index] = label
    end
    items[#items + 1] = T("Lepas profil dari aplikasi ini", "Release the profile from this app")
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    builder.setTitle(appName)
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which + 1 <= #profiles then
                local chosen = profiles[which + 1]
                local map = khusus.getAssignments()
                map[package] = chosen.id
                khusus.saveAssignments(map)
                service.speak(T("Profil ", "Profile ") .. chosen.name .. T(" dipasang ke ", " assigned to ") .. appName .. ".")
            elseif which == #profiles then
                local map = khusus.getAssignments()
                khusus.releaseAssignment(map, package)
                khusus.saveAssignments(map)
                service.speak(T("Profil dilepas dari ", "Profile released from ") .. appName .. ".")
            end
            khusus.showAssignments()
        end
    })
    presentDialog(builder)
end

function khusus.showAssignments()
    local lookup = {}
    for _, item in ipairs(khusus.allProfiles()) do
        lookup[item.id] = item
    end
    local entries = {}
    for package, id in pairs(khusus.getAssignments()) do
        local profile = lookup[id]
        if profile ~= nil then
            entries[#entries + 1] = { package = package, label = khusus.appLabel(package), profile = profile }
        end
    end
    if #entries == 0 then
        service.speak(T("Belum ada aplikasi yang memakai profil.", "No app is using a profile yet."))
        khusus.showProfileMenu()
        return
    end
    table.sort(entries, function(first, second)
        return first.label:lower() < second.label:lower()
    end)
    local items = {}
    for index, entry in ipairs(entries) do
        items[index] = entry.label .. ": " .. entry.profile.name
    end
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Aplikasi yang memakai profil", "Apps using a profile"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which + 1 <= #entries then
                khusus.showAssignmentChoice(entries[which + 1].package)
            else
                khusus.showProfileMenu()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showProfileDetail(id)
    local profile = khusus.findProfile(id)
    if profile == nil then
        khusus.showProfileList()
        return
    end
    local actions = { "apply", "assign", "view" }
    local items = {
        T("Terapkan sekarang", "Apply now"),
        T("Pasang ke aplikasi", "Assign to an app"),
        T("Lihat isi profil", "View profile contents")
    }
    if profile.custom then
        actions[#actions + 1] = "edit"
        items[#items + 1] = T("Ubah nama dan isi profil", "Edit profile name and contents")
        actions[#actions + 1] = "delete"
        items[#items + 1] = T("Hapus profil", "Delete profile")
    end
    actions[#actions + 1] = "back"
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    local detailTitle = T("Profil ", "Profile ") .. profile.name
    if khusus.profileMatches(profile) then
        local active = khusus.activeProfile()
        if active ~= nil and active.id == profile.id then
            detailTitle = detailTitle .. T(" (aktif)", " (active)")
        end
    end
    builder.setTitle(detailTitle)
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            local action = actions[which + 1]
            if action == "apply" then
                khusus.applyProfile(profile)
                service.speak(T("Profil ", "Profile ") .. profile.name .. T(" diterapkan dan sekarang aktif.", " applied and now active."))
                khusus.showProfileDetail(id)
            elseif action == "assign" then
                khusus.showAppPicker(id)
            elseif action == "view" then
                khusus.showNotice(profile.name, khusus.describeProfile(profile), function()
                    khusus.showProfileDetail(id)
                end)
            elseif action == "edit" then
                khusus.showProfileForm(id, nil)
            elseif action == "delete" then
                khusus.showConfirm(T("Hapus profil", "Delete profile"), T("Hapus profil ", "Delete profile ") .. profile.name .. T("? Aplikasi yang memakai profil ini juga dilepas.", "? Apps using this profile are also released."), function()
                    khusus.deleteProfile(id)
                    service.speak(T("Profil dihapus.", "Profile deleted."))
                    khusus.showProfileList()
                end, function()
                    khusus.showProfileDetail(id)
                end)
            else
                khusus.showProfileList()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showProfileList()
    local list = khusus.allProfiles()
    local active = khusus.activeProfile()
    local items = {}
    for index, item in ipairs(list) do
        local label = item.name
        if not item.custom then
            label = label .. T(" (bawaan)", " (built-in)")
        end
        if active ~= nil and active.id == item.id then
            label = label .. T(" (aktif)", " (active)")
        end
        items[index] = label
    end
    items[#items + 1] = T("Kembali", "Back")
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Daftar profil", "Profile list"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which + 1 <= #list then
                khusus.showProfileDetail(list[which + 1].id)
            else
                khusus.showProfileMenu()
            end
        end
    })
    presentDialog(builder)
end

function khusus.showProfileMenu()
    local items = {
        T("Profil otomatis per aplikasi: ", "Automatic profile per app: ") .. stateText(getFlag("profil_otomatis", false)),
        T("Daftar profil (aktif: ", "Profile list (active: ") .. khusus.activeProfileText() .. ")",
        T("Buat profil baru", "Create new profile"),
        T("Aplikasi yang memakai profil", "Apps using a profile"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Profil dikte suara, aktif: ", "Dictation profiles, active: ") .. khusus.activeProfileText())
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            if which == 0 then
                toggleFlag("profil_otomatis", false)
                khusus.showProfileMenu()
            elseif which == 1 then
                khusus.showProfileList()
            elseif which == 2 then
                khusus.showProfileForm(nil, nil)
            elseif which == 3 then
                khusus.showAssignments()
            else
                showBjrSettings()
            end
        end
    })
    presentDialog(builder)
end

khusus.exclusiveStyleKeys = { "gaya_singkatan", "gaya_jaksel", "gaya_gagap", "gaya_cadel" }

function khusus.toggleStyleFlag(key)
    local value = toggleFlag(key, false)
    if value then
        local editor = getPrefs().edit()
        for _, other in ipairs(khusus.exclusiveStyleKeys) do
            if other ~= key then
                editor.putBoolean(other, false)
            end
        end
        editor.apply()
    end
    return value
end

showBjrSettings = function()
    profileLayer.values = nil
    if not khusus.pro.require() then
        return
    end
    local items = {
        T("Huruf kapital otomatis: ", "Automatic capital letters: ") .. stateText(getFlag("kapital_otomatis")),
        T("Baris baru setelah teks: ", "New line after text: ") .. stateText(getFlag("baris_baru")),
        T("Gunakan tanda baca otomatis: ", "Use automatic punctuation: ") .. stateText(getFlag("tanda_baca_otomatis", false)),
        T("Spasi setelah teks: ", "Space after text: ") .. stateText(getFlag("spasi_setelah_teks", false)),
        T("Gaya singkatan umum: ", "Common abbreviation style: ") .. stateText(getFlag("gaya_singkatan", false)),
        T("Gunakan singkatan jaksel: ", "Use Jaksel abbreviations: ") .. stateText(getFlag("gaya_jaksel", false)),
        T("Gaya bicara gagap: ", "Stuttering speech style: ") .. stateText(getFlag("gaya_gagap", false)),
        T("Gaya bicara cadel: ", "Lisping speech style: ") .. stateText(getFlag("gaya_cadel", false)),
        T("Ejaan rapi: ", "Neat spelling: ") .. stateText(getFlag("ejaan_rapi", false)),
        T("Bersihkan kata isian dan pengulangan: ", "Remove filler words and repeats: ") .. stateText(getFlag("bersihkan_isian", true)),
        T("Profil dikte suara, aktif: ", "Dictation profiles, active: ") .. khusus.activeProfileText(),
        T("Mode offline penuh (hemat baterai): ", "Full offline mode (saves battery): ") .. stateText(getFlag("offline_penuh", false)),
        T("Statistik dan pengingat dikte", "Dictation statistics and reminders"),
        T("Koreksi tanggal hijriah: ", "Hijri date correction: ") .. khusus.waktu.correctionLabel(),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Pengaturan bjr", "Bjr settings"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            if which == 0 then
                toggleFlag("kapital_otomatis")
                feedbackUI()
                showBjrSettings()
            elseif which == 1 then
                toggleFlag("baris_baru")
                feedbackUI()
                showBjrSettings()
            elseif which == 2 then
                toggleFlag("tanda_baca_otomatis", false)
                feedbackUI()
                showBjrSettings()
            elseif which == 3 then
                toggleFlag("spasi_setelah_teks", false)
                feedbackUI()
                showBjrSettings()
            elseif which == 4 then
                khusus.toggleStyleFlag("gaya_singkatan")
                feedbackUI()
                showBjrSettings()
            elseif which == 5 then
                khusus.toggleStyleFlag("gaya_jaksel")
                feedbackUI()
                showBjrSettings()
            elseif which == 6 then
                khusus.toggleStyleFlag("gaya_gagap")
                feedbackUI()
                showBjrSettings()
            elseif which == 7 then
                khusus.toggleStyleFlag("gaya_cadel")
                feedbackUI()
                showBjrSettings()
            elseif which == 8 then
                toggleFlag("ejaan_rapi", false)
                feedbackUI()
                showBjrSettings()
            elseif which == 9 then
                toggleFlag("bersihkan_isian", true)
                feedbackUI()
                showBjrSettings()
            elseif which == 10 then
                feedbackUI()
                khusus.showProfileMenu()
            elseif which == 11 then
                local enabled = toggleFlag("offline_penuh", false)
                khusus.resetService()
                feedbackUI()
                if enabled then
                    service.speak(T("Mode offline penuh aktif. Dikte dan fitur lain berjalan tanpa internet. Terjemahan dan koreksi tulisan lewat internet dimatikan.", "Full offline mode is on. Dictation and other features run without internet. Online translation and text correction are turned off."))
                else
                    service.speak(T("Mode offline penuh nonaktif. Terjemahan dan koreksi tulisan lewat internet bisa dipakai lagi.", "Full offline mode is off. Online translation and text correction can be used again."))
                end
                showBjrSettings()
            elseif which == 12 then
                feedbackUI()
                khusus.stats.showMenu()
            elseif which == 13 then
                khusus.waktu.cycleCorrection()
                feedbackUI()
                service.speak(T("Koreksi tanggal hijriah ", "Hijri date correction ") .. khusus.waktu.correctionLabel() .. ".")
                showBjrSettings()
            else
                feedbackUI()
                dialog.dismiss()
                showMainSettings()
            end
        end
    })
    presentDialog(builder)
end

local function showUserNote()
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Catatan khusus pengguna bjr", "Special note for Bjr users"))
    builder.setMessage(T("Selamat menggunakan untuk para kaum-kaum dhuafa! Dan juga para kaum-kaum lansia yang tidak mau ribet dengan pengaturan input suara. Wak wak wak wak wak. Saya suguhkan input suara simpel, padat, dan berisi. Langsung bisa dirasakan simple pengaturannya, cuma sedikit, tanpa kode api tanpa apa pun itu. Wes, pokoknya aman lah, tanpa kendala. Pokoknya, aja khusus khususkan untuk para kaum-kaum lansia yang tidak mau ribet. Wak wak wak wak. Kalau para kaum-kaum muda-mudi, ya nggak usah gunakan yang ini ya, karena alat ini dikhususkan untuk para kaum-kaum dhuafa dan para kaum-kaum lansia. Wak wak wak wak wak. Terima kasih. Alat ini dikembangkan oleh Mbah Dadang, asli orang Banjarnegara. Orangnya tidak sombong dan rajin menabung di sepiteng. Wak wak wak wak wak.", "Welcome to all the underprivileged folks! And also to the elderly folks who do not want any hassle with voice input settings. Wak wak wak wak wak. I present you a voice input that is simple, compact, and full of substance. You can feel it right away: the settings are simple, just a few, with no codes or anything like that. Well, anyway, it is safe and without trouble. Anyway, it is made especially for the elderly folks who do not want any hassle. Wak wak wak wak. If you are a young person, please do not use this one, because this tool is made especially for the underprivileged folks and the elderly folks. Wak wak wak wak wak. Thank you. This tool was developed by Mbah Dadang, a native of Banjarnegara. He is humble and diligent at saving money in the septic tank. Wak wak wak wak wak.") .. "\n\n" .. T("Khusus untuk para janda dan jandaan sedunia, yang perkasa, mandiri, dan anti ribet! Alat ini cocok sekali untuk Anda. Kenapa? Pertama, alat ini setia, tidak pernah ghosting, dan tidak pernah bilang aku butuh waktu sendiri. Kedua, alat ini tidak minta uang belanja, tidak minta dimasakin, dan tidak pernah lupa hari ulang tahun karena memang tidak punya. Ketiga, kalau Anda bicara, alat ini mendengarkan sampai selesai tanpa memotong dan tanpa bilang terserah. Wak wak wak wak wak. Kalau suatu saat alat ini ngambek, jangan langsung diblokir, cek dulu pengaturannya, siapa tahu cuma salah paham. Para janda dan jandaan, tetap semangat, tetap bahagia, dan tetap dikte dengan suara lantang! Wak wak wak wak wak. Bagi antum-antum yang mau berbagi uang atau rokok, Mbah Dadang siap menampung. Wak wak wak wak wak.\n\nSalam gokil dari pengembang alat ini: Mbah Dadang, asli orang Banjarnegara.", "Especially for all the widows and divorcees of the world, who are strong, independent, and hassle-free! This tool suits you perfectly. Why? First, this tool is loyal, never ghosts you, and never says I need some time alone. Second, this tool never asks for household money, never asks to be cooked for, and never forgets your birthday because it simply does not have one. Third, when you speak, this tool listens until you finish, without interrupting and without saying whatever. Wak wak wak wak wak. If one day this tool sulks, do not block it right away, check its settings first, maybe it is just a misunderstanding. Dear widows and divorcees, stay cheerful, stay happy, and keep dictating out loud! Wak wak wak wak wak. For you folks who want to share some money or cigarettes, Mbah Dadang is ready to accept them. Wak wak wak wak wak.\n\nFunny greetings from the developer of this tool: Mbah Dadang, a native of Banjarnegara."))
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            showMainSettings()
        end
    })
    presentDialog(builder)
end

showMainSettings = function()
    profileLayer.values = nil
    local proOn = khusus.pro.safeActive()
    local assistantLabel = T("Asisten Bjr: terkunci, perlu aktivasi pro", "Bjr assistant: locked, pro activation needed")
    local bjrLabel = T("Pengaturan bjr (pro, terkunci)", "Bjr settings (pro, locked)")
    local khususLabel = T("Pengaturan khusus bjr (pro, terkunci)", "Bjr special settings (pro, locked)")
    if proOn then
        assistantLabel = T("Asisten Bjr: ", "Bjr assistant: ") .. stateText(getFlag("asisten_aktif", false))
        bjrLabel = T("Pengaturan bjr", "Bjr settings")
        khususLabel = T("Pengaturan khusus bjr", "Bjr special settings")
    end
    local items = {
        T("Tentang dan petunjuk penggunaan Bjr", "About and user guide for Bjr"),
        T("Catatan khusus pengguna bjr", "Special note for Bjr users"),
        assistantLabel,
        T("Bahasa pengenalan suara Bjr: ", "Bjr speech recognition language: ") .. languageNames[getLanguageIndex()],
        T("Jeda napas jadi tanda baca Bjr: ", "Bjr breath pause as punctuation: ") .. stateText(getFlag("jeda_napas")),
        T("Sensitivitas jeda napas Bjr: ", "Bjr breath pause sensitivity: ") .. pauseNames[getPauseIndex()],
        T("Ucapkan hasil dikte Bjr: ", "Speak Bjr dictation result: ") .. stateText(getFlag("ucapkan_hasil")),
        T("Gunakan getaran Bjr: ", "Use Bjr vibration: ") .. vibrationModeNames[getVibrationMode()],
        T("Kekuatan getaran: ", "Vibration strength: ") .. getVibrationStrength() .. T(" persen", " percent"),
        bjrLabel,
        khususLabel,
        T("Cadangkan dan kembalikan pengaturan Bjr", "Back up and restore Bjr settings"),
        T("Unduh paket bahasa offline", "Download offline language pack"),
        T("Tutup", "Close")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(extensionName)
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            if which == 0 then
                feedbackUI()
                showAboutSettings()
            elseif which == 1 then
                feedbackUI()
                showUserNote()
            elseif which == 2 then
                if not khusus.pro.require() then
                    return
                end
                toggleFlag("asisten_aktif", false)
                feedbackUI()
                showMainSettings()
            elseif which == 3 then
                feedbackUI()
                showLanguageSettings()
            elseif which == 4 then
                toggleFlag("jeda_napas")
                feedbackUI()
                showMainSettings()
            elseif which == 5 then
                feedbackUI()
                showSensitivitySettings()
            elseif which == 6 then
                toggleFlag("ucapkan_hasil")
                feedbackUI()
                showMainSettings()
            elseif which == 7 then
                local nextMode = getVibrationMode() % #vibrationModeNames + 1
                getPrefs().edit().putInt("getaran_mode", nextMode).apply()
                if nextMode > 1 then
                    vibrateOnce(vibrationDurations[nextMode])
                end
                showMainSettings()
            elseif which == 8 then
                feedbackUI()
                showVibrationStrengthSettings()
            elseif which == 9 then
                feedbackUI()
                showBjrSettings()
            elseif which == 10 then
                feedbackUI()
                showKhususSettings()
            elseif which == 11 then
                feedbackUI()
                khusus.showBackupMenu()
            elseif which == 12 then
                feedbackUI()
                if khusus.openLanguagePackDownload() then
                    service.speak(T("Pilih Pengenalan suara offline, lalu unduh Bahasa Indonesia.", "Choose Offline speech recognition, then download your language."))
                else
                    service.speak(T("Pengaturan HP gagal dibuka.", "The phone settings could not be opened."))
                end
            else
                feedbackUI()
                dialog.dismiss()
            end
        end
    })
    presentDialog(builder)
end

function settingsExit.release()
    local player = settingsExit.player
    settingsExit.player = nil
    if player ~= nil then
        pcall(function()
            player.stop()
        end)
        pcall(function()
            player.release()
        end)
    end
end

function khusus.releaseIntro()
    local player = khusus.introPlayer
    khusus.introPlayer = nil
    if player ~= nil then
        pcall(function()
            player.stop()
        end)
        pcall(function()
            player.release()
        end)
    end
end

function khusus.introDirectories()
    local directories = {}
    local function add(path)
        if type(path) ~= "string" or path:find("\n", 1, true) ~= nil then
            return
        end
        local directory = path:gsub("\\", "/")
        if directory:lower():find("%.lua$") then
            directory = directory:match("^(.*)/[^/]*$") or ""
        end
        directory = directory:gsub("/+$", "")
        if directory ~= "" then
            directories[#directories + 1] = directory
        end
    end
    for level = 1, 20 do
        local found, info = pcall(function()
            return debug.getinfo(level, "S")
        end)
        if not found or info == nil then
            break
        end
        local origin = info.source
        if type(origin) == "string" and origin:sub(1, 1) == "@" then
            add(origin:sub(2))
        end
    end
    for _, variable in ipairs({ "luapath", "luadir" }) do
        local read, value = pcall(function()
            return _G[variable]
        end)
        if read then
            add(value)
        end
    end
    local read, searchPath = pcall(function()
        return package.path
    end)
    if read and type(searchPath) == "string" then
        for entry in searchPath:gmatch("[^;]+") do
            add((entry:gsub("[/\\]%?.*$", "")))
        end
    end
    local root = "/storage/emulated/0/Plugin"
    add(root .. "/" .. extensionName)
    local listed, names = pcall(function()
        return Arrays.asList(File(root).list())
    end)
    if listed and names ~= nil then
        local expected = extensionName:lower():gsub("[^%w]", "")
        local others = {}
        for index = 0, names.size() - 1 do
            local name = tostring(names.get(index))
            if name:lower():gsub("[^%w]", "") == expected then
                add(root .. "/" .. name)
            else
                others[#others + 1] = root .. "/" .. name
            end
        end
        for _, path in ipairs(others) do
            add(path)
        end
    end
    add(root)
    return directories
end

function khusus.introFile()
    for _, directory in ipairs(khusus.introDirectories()) do
        local found, file = pcall(function()
            return File(directory .. "/Bjr.mp3")
        end)
        if found and file ~= nil and file.isFile() then
            return file.getAbsolutePath()
        end
    end
    return nil
end

function khusus.exitFile()
    for _, directory in ipairs(khusus.introDirectories()) do
        for _, name in ipairs({ "bjr2.mp3", "Bjr2.mp3" }) do
            local found, file = pcall(function()
                return File(directory .. "/" .. name)
            end)
            if found and file ~= nil and file.isFile() then
                return file.getAbsolutePath()
            end
        end
    end
    return nil
end

function settingsExit.play()
    khusus.introToken = khusus.introToken + 1
    khusus.releaseIntro()
    settingsExit.release()
    local prepared = pcall(function()
        local path = khusus.exitFile()
        if path == nil then
            return
        end
        local player = MediaPlayer()
        settingsExit.player = player
        player.setDataSource(path)
        player.setOnPreparedListener(MediaPlayer.OnPreparedListener{
            onPrepared = function(mp)
                if settingsExit.player == mp then
                    pcall(function() mp.start() end)
                end
            end
        })
        player.setOnCompletionListener(MediaPlayer.OnCompletionListener{
            onCompletion = function(mp)
                if settingsExit.player == mp then
                    settingsExit.release()
                end
            end
        })
        player.setOnErrorListener(MediaPlayer.OnErrorListener{
            onError = function(mp, what, extra)
                if settingsExit.player == mp then
                    settingsExit.release()
                end
                return true
            end
        })
        player.prepareAsync()
    end)
    if not prepared then
        settingsExit.release()
    end
end

function settingsExit.schedule(token)
    pcall(function()
        khusus.handler.postDelayed(function()
            if token == settingsExit.token and settingsExit.count == 0 then
                settingsExit.play()
            end
        end, 400)
    end)
end

khusus.gate = {
    whatsappNumber = "6285134573304",
    whatsappDisplay = "+62 851-3457-3304",
    key = "9e5126ffdec9dfc718c76aed7b7e2375",
    verifiedStamp = nil,
    modulus = 4294967296,
    constants = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    }
}

function khusus.gate.bitAnd(a, b)
    local result = 0
    local power = 1
    for _ = 1, 32 do
        local x = a % 2
        local y = b % 2
        if x == 1 and y == 1 then
            result = result + power
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        power = power * 2
    end
    return result
end

function khusus.gate.bitXor(a, b)
    local result = 0
    local power = 1
    for _ = 1, 32 do
        local x = a % 2
        local y = b % 2
        if x ~= y then
            result = result + power
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        power = power * 2
    end
    return result
end

function khusus.gate.rotateRight(value, count)
    local divisor = 2 ^ count
    return math.floor(value / divisor) + (value % divisor) * (2 ^ (32 - count))
end

function khusus.gate.shiftRight(value, count)
    return math.floor(value / (2 ^ count))
end

function khusus.gate.toBytes(text)
    local bytes = {}
    for index = 1, #text do
        bytes[index] = string.byte(text, index)
    end
    return bytes
end

function khusus.gate.sha256(input)
    local xor = khusus.gate.bitXor
    local band = khusus.gate.bitAnd
    local rotr = khusus.gate.rotateRight
    local shr = khusus.gate.shiftRight
    local modulus = khusus.gate.modulus
    local constants = khusus.gate.constants

    local message = {}
    for index = 1, #input do
        message[index] = input[index]
    end
    local bitLength = #input * 8
    message[#message + 1] = 128
    while #message % 64 ~= 56 do
        message[#message + 1] = 0
    end
    local high = math.floor(bitLength / modulus)
    local low = bitLength % modulus
    for _, word in ipairs({ high, low }) do
        message[#message + 1] = math.floor(word / 16777216) % 256
        message[#message + 1] = math.floor(word / 65536) % 256
        message[#message + 1] = math.floor(word / 256) % 256
        message[#message + 1] = word % 256
    end

    local state = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 }

    for offset = 0, #message - 1, 64 do
        local w = {}
        for t = 1, 16 do
            local base = offset + (t - 1) * 4
            w[t] = message[base + 1] * 16777216 + message[base + 2] * 65536 + message[base + 3] * 256 + message[base + 4]
        end
        for t = 17, 64 do
            local w15 = w[t - 15]
            local w2 = w[t - 2]
            local s0 = xor(xor(rotr(w15, 7), rotr(w15, 18)), shr(w15, 3))
            local s1 = xor(xor(rotr(w2, 17), rotr(w2, 19)), shr(w2, 10))
            w[t] = (w[t - 16] + s0 + w[t - 7] + s1) % modulus
        end
        local a, b, c, d, e, f, g, h = state[1], state[2], state[3], state[4], state[5], state[6], state[7], state[8]
        for t = 1, 64 do
            local sum1 = xor(xor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
            local choice = xor(band(e, f), band(modulus - 1 - e, g))
            local temp1 = (h + sum1 + choice + constants[t] + w[t]) % modulus
            local sum0 = xor(xor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
            local majority = xor(xor(band(a, b), band(a, c)), band(b, c))
            local temp2 = (sum0 + majority) % modulus
            h = g
            g = f
            f = e
            e = (d + temp1) % modulus
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % modulus
        end
        state[1] = (state[1] + a) % modulus
        state[2] = (state[2] + b) % modulus
        state[3] = (state[3] + c) % modulus
        state[4] = (state[4] + d) % modulus
        state[5] = (state[5] + e) % modulus
        state[6] = (state[6] + f) % modulus
        state[7] = (state[7] + g) % modulus
        state[8] = (state[8] + h) % modulus
    end

    local digest = {}
    for _, word in ipairs(state) do
        digest[#digest + 1] = math.floor(word / 16777216) % 256
        digest[#digest + 1] = math.floor(word / 65536) % 256
        digest[#digest + 1] = math.floor(word / 256) % 256
        digest[#digest + 1] = word % 256
    end
    return digest
end

function khusus.gate.hmac(keyText, dataText)
    local xor = khusus.gate.bitXor
    local key = khusus.gate.toBytes(keyText)
    if #key > 64 then
        key = khusus.gate.sha256(key)
    end
    while #key < 64 do
        key[#key + 1] = 0
    end
    local inner = {}
    local outer = {}
    for index = 1, 64 do
        inner[index] = xor(key[index], 54)
        outer[index] = xor(key[index], 92)
    end
    for _, byte in ipairs(khusus.gate.toBytes(dataText)) do
        inner[#inner + 1] = byte
    end
    for _, byte in ipairs(khusus.gate.sha256(inner)) do
        outer[#outer + 1] = byte
    end
    return khusus.gate.sha256(outer)
end

function khusus.gate.cleanName(name)
    local text = tostring(name or ""):gsub("[ \t\n\r\f\v]+", " ")
    text = text:gsub("^ ", ""):gsub(" $", "")
    return text
end

function khusus.gate.normalName(name)
    local text = khusus.gate.cleanName(name):gsub("[A-Z]", function(letter)
        return string.char(string.byte(letter) + 32)
    end)
    return text
end

function khusus.gate.codeText(text)
    return (tostring(text or ""):gsub("[^0-9A-Za-z]", ""):upper())
end

function khusus.gate.validName(name)
    local normal = khusus.gate.normalName(name)
    if #normal < 3 or #normal > 60 then
        return false
    end
    if normal:find("[^A-Za-z\128-\255 '%.%-]") then
        return false
    end
    return normal:find("[A-Za-z\128-\255]") ~= nil
end

function khusus.gate.code(name)
    local digest = khusus.gate.hmac(khusus.gate.key, khusus.gate.normalName(name))
    local hex = ""
    for index = 1, 5 do
        hex = hex .. string.format("%02X", math.floor(digest[index]))
    end
    return hex
end

function khusus.gate.isActive()
    local prefs = getPrefs()
    if not prefs.getBoolean("aktivasi_ok", false) then
        return false
    end
    local name = tostring(prefs.getString("aktivasi_nama", ""))
    local code = tostring(prefs.getString("aktivasi_kode", ""))
    if not khusus.gate.validName(name) then
        return false
    end
    local stamp = name .. "\n" .. code
    if khusus.gate.verifiedStamp == stamp then
        return true
    end
    if code ~= khusus.gate.code(name) then
        return false
    end
    khusus.gate.verifiedStamp = stamp
    return true
end

function khusus.gate.open(url, failMessage)
    local opened = pcall(function()
        local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        this.startActivity(intent)
    end)
    if not opened then
        service.speak(failMessage)
    end
end

function khusus.gate.require()
    local checked, active = pcall(khusus.gate.isActive)
    if checked and active then
        return true
    end
    khusus.gate.showWelcome()
    return false
end

function khusus.gate.activate(name, code)
    pcall(function()
        getPrefs().edit().putString("aktivasi_nama", name).putString("aktivasi_kode", code).putBoolean("aktivasi_ok", true).putBoolean("petunjuk_awal_dilihat", true).apply()
    end)
    local checked, active = pcall(khusus.gate.isActive)
    if not (checked and active) then
        return false
    end
    service.speak(T("Aktivasi berhasil. Selamat menggunakan alat ini.", "Activation succeeded. Enjoy using this tool."))
    showGuideText(true)
    return true
end

function khusus.gate.showForm(nameText, codeText, notice)
    local layout = LinearLayout(this)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(48, 32, 48, 16)

    local info = TextView(this)
    local infoText = T("Isi kotak edit pertama dengan nama pengguna memakai nama asli sesuai yang terdaftar di nomor NIK, hanya huruf tanpa angka dan simbol, lalu klik tombol Minta kode aktivasi. Anda akan otomatis dibawa ke WhatsApp pengembang di nomor ", "Fill the first edit box with a username that is your real name as registered on your ID number, letters only without numbers or symbols, then click the Request activation code button. You will be taken to the developer's WhatsApp at number ") .. khusus.gate.whatsappDisplay .. T(". Setelah kode aktivasi dikirim pengembang, jalankan alat ini lagi, masukkan kode itu di kotak edit kedua, lalu klik tombol Lanjut.", ". After the developer sends the activation code, run this tool again, enter the code in the second edit box, then click the Continue button.")
    if notice ~= nil then
        infoText = notice .. "\n\n" .. infoText
    end
    info.setText(infoText)
    layout.addView(info)

    local nameField = EditText(this)
    nameField.setHint(T("Nama pengguna sesuai nama asli di NIK", "Username as your real name on your ID"))
    nameField.setContentDescription(T("Nama pengguna sesuai nama asli di NIK", "Username as your real name on your ID"))
    nameField.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_CAP_WORDS)
    nameField.setText(nameText or "")
    layout.addView(nameField)

    local codeField = EditText(this)
    codeField.setHint(T("Kode aktivasi dari pengembang", "Activation code from the developer"))
    codeField.setContentDescription(T("Kode aktivasi dari pengembang", "Activation code from the developer"))
    codeField.setInputType(InputType.TYPE_CLASS_TEXT)
    codeField.setText(codeText or "")
    layout.addView(codeField)

    local scroll = ScrollView(this)
    scroll.addView(layout)

    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Nama pengguna dan kode aktivasi", "Username and activation code"))
    builder.setView(scroll)

    builder.setPositiveButton(T("Lanjut", "Continue"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            local name = khusus.gate.cleanName(nameField.getText())
            local code = khusus.gate.codeText(codeField.getText())
            dialog.dismiss()
            local problem = nil
            if not khusus.gate.validName(name) then
                problem = T("Nama pengguna tidak valid. Isi dengan nama asli sepanjang tiga sampai enam puluh karakter, hanya huruf, spasi, titik, apostrof, atau tanda hubung.", "The username is not valid. Enter your real name with three to sixty characters, using only letters, spaces, periods, apostrophes, or hyphens.")
            elseif code == "" then
                problem = T("Kode aktivasi belum diisi. Klik Minta kode aktivasi untuk meminta kode ke pengembang.", "The activation code is empty. Click Request activation code to ask the developer for a code.")
            elseif code ~= khusus.gate.code(name) then
                problem = T("Kode aktivasi tidak sesuai dengan nama pengguna. Pastikan nama pengguna sama dengan yang Anda kirim ke pengembang.", "The activation code does not match the username. Make sure the username is the same as the one you sent to the developer.")
            end
            if problem ~= nil then
                khusus.gate.showForm(name, code, problem)
                service.speak(problem)
                return
            end
            if not khusus.gate.activate(name, code) then
                local failed = T("Aktivasi gagal disimpan. Silakan coba lagi.", "Activation could not be saved. Please try again.")
                khusus.gate.showForm(name, code, failed)
                service.speak(failed)
            end
        end
    })

    builder.setNeutralButton(T("Minta kode aktivasi", "Request activation code"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            local name = khusus.gate.cleanName(nameField.getText())
            local code = khusus.gate.codeText(codeField.getText())
            dialog.dismiss()
            if not khusus.gate.validName(name) then
                local problem = T("Isi nama pengguna dulu dengan nama asli tanpa angka dan simbol, lalu klik Minta kode aktivasi.", "Fill in the username first with your real name without numbers or symbols, then click Request activation code.")
                khusus.gate.showForm(name, code, problem)
                service.speak(problem)
                return
            end
            pcall(function()
                getPrefs().edit().putString("aktivasi_nama_draf", name).apply()
            end)
            local message = T("Assalamualaikum, saya minta kode aktivasi ", "Hello, I would like to request an activation code for ") .. extensionName .. ".\n" .. T("Nama: ", "Name: ") .. name
            khusus.gate.open("https://wa.me/" .. khusus.gate.whatsappNumber .. "?text=" .. khusus.urlEncode(message), T("WhatsApp gagal dibuka. Hubungi pengembang di nomor ", "WhatsApp could not be opened. Contact the developer at number ") .. khusus.gate.whatsappDisplay)
        end
    })

    builder.setNegativeButton(T("Tutup", "Close"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
        end
    })
    presentDialog(builder)
end

function khusus.gate.showWelcome()
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Selamat datang di ", "Welcome to ") .. extensionName)
    builder.setMessage(T("Selamat datang, pengguna baru maupun pengguna lama. Alat ini dibangun oleh Mbah Dadang, asli orang Banjarnegara. Sebelum masuk ke petunjuk dan penggunaan, Anda diwajibkan membuat nama pengguna dengan nama asli yang terdaftar di nomor NIK untuk meminta kode aktivasi. Selama aktivasi belum berhasil, semua fitur dan asisten tetap terkunci walaupun alat dijalankan. Tekan Lanjut untuk mengisi nama pengguna.", "Welcome, new and returning users. This tool was built by Mbah Dadang, a native of Banjarnegara. Before entering the user guide, you are required to create a username with your real name as registered on your ID number to request an activation code. Until activation succeeds, all features and the assistant stay locked even when the tool is run. Press Continue to fill in the username."))
    builder.setPositiveButton(T("Lanjut", "Continue"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            local draft = ""
            pcall(function()
                draft = tostring(getPrefs().getString("aktivasi_nama_draf", ""))
            end)
            khusus.gate.showForm(draft, "", nil)
        end
    })
    builder.setNegativeButton(T("Tutup", "Close"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
        end
    })
    presentDialog(builder)
end

khusus.pro = {
    key = "716be2999e7fc7c12a6cf9bfa37e2ea0",
    verifiedStamp = nil,
    cachedDevice = nil
}

function khusus.pro.deviceId()
    if khusus.pro.cachedDevice ~= nil then
        return khusus.pro.cachedDevice
    end
    local ok, value = pcall(function()
        return luajava.bindClass("android.provider.Settings$Secure").getString(this.getContentResolver(), "android_id")
    end)
    if not ok or value == nil then
        return nil
    end
    local text = tostring(value):gsub("[^0-9A-Za-z]", "")
    if #text < 8 then
        return nil
    end
    khusus.pro.cachedDevice = text:lower()
    return khusus.pro.cachedDevice
end

function khusus.pro.code(name, deviceId)
    local digest = khusus.gate.hmac(khusus.pro.key, khusus.gate.normalName(name) .. "|" .. deviceId)
    local hex = ""
    for index = 1, 6 do
        hex = hex .. string.format("%02X", math.floor(digest[index]))
    end
    return hex
end

function khusus.pro.isActive()
    local prefs = getPrefs()
    if not prefs.getBoolean("pro_ok", false) then
        return false
    end
    local name = tostring(prefs.getString("pro_nama", ""))
    local code = tostring(prefs.getString("pro_kode", ""))
    if not khusus.gate.validName(name) then
        return false
    end
    local deviceId = khusus.pro.deviceId()
    if deviceId == nil then
        return false
    end
    local stamp = name .. "\n" .. code .. "\n" .. deviceId
    if khusus.pro.verifiedStamp == stamp then
        return true
    end
    if code ~= khusus.pro.code(name, deviceId) then
        return false
    end
    khusus.pro.verifiedStamp = stamp
    return true
end

function khusus.pro.safeActive()
    local checked, active = pcall(khusus.pro.isActive)
    return checked and active == true
end

proLock.check = khusus.pro.safeActive

function khusus.pro.require()
    if khusus.pro.safeActive() then
        return true
    end
    local message = T("Silakan aktivasi dulu untuk menggunakan fitur pro ini.", "Please activate first to use this pro feature.")
    service.speak(message)
    local draft = ""
    pcall(function()
        local prefs = getPrefs()
        draft = tostring(prefs.getString("pro_nama_draf", ""))
        if draft == "" then
            draft = tostring(prefs.getString("aktivasi_nama", ""))
        end
    end)
    khusus.pro.showForm(draft, "", message)
    return false
end

function khusus.pro.activate(name, code)
    pcall(function()
        getPrefs().edit().putString("pro_nama", name).putString("pro_kode", code).putBoolean("pro_ok", true).apply()
    end)
    khusus.pro.verifiedStamp = nil
    if not khusus.pro.safeActive() then
        pcall(function()
            getPrefs().edit().remove("pro_ok").remove("pro_nama").remove("pro_kode").apply()
        end)
        return false
    end
    local message = T("Selamat, Anda sudah bisa menggunakan fitur pro ini.", "Congratulations, you can now use this pro feature.")
    service.speak(message)
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Aktivasi pro berhasil", "Pro activation succeeded"))
    builder.setMessage(message)
    builder.setPositiveButton(T("Oke", "OK"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            showMainSettings()
        end
    })
    presentDialog(builder)
    return true
end

function khusus.pro.showForm(nameText, codeText, notice)
    local deviceId = khusus.pro.deviceId()
    local layout = LinearLayout(this)
    layout.setOrientation(LinearLayout.VERTICAL)
    layout.setPadding(48, 32, 48, 16)

    local info = TextView(this)
    local infoText = T("Asisten Bjr: Aktif, Pengaturan bjr, dan Pengaturan khusus bjr beserta seluruh isinya dan fitur asisten adalah fitur pro seharga Rp15.000 untuk satu perangkat. Biaya aktivasi dibayar lewat transfer GoPay ke nomor yang sama dengan nomor WhatsApp pengembang di bawah ini. Tanpa aktivasi pro, proses pengetikan tetap bisa digunakan. Isi kotak edit pertama dengan nama asli pengguna, lalu klik tombol Minta aktivasi. Anda akan dibawa ke WhatsApp pengembang di nomor ", "Bjr assistant: On, Bjr settings, and Bjr special settings, with everything inside them and the assistant features, are pro features priced at Rp15,000 for one device. The activation fee is paid by GoPay transfer to the same number as the developer's WhatsApp number below. Without pro activation, typing can still be used. Fill the first edit box with the user's real name, then click the Request activation button. You will be taken to the developer's WhatsApp at number ") .. khusus.gate.whatsappDisplay .. T(". Setelah kode aktivasi dikirim pengembang, buka lagi menu ini, masukkan kode di kotak edit kedua, lalu klik tombol Aktifkan. Satu kode aktivasi hanya berlaku untuk satu perangkat. ID perangkat ini: ", ". After the developer sends the activation code, open this menu again, enter the code in the second edit box, then click the Activate button. One activation code is valid for one device only. This device ID: ") .. (deviceId or T("tidak terbaca", "unreadable"))
    if notice ~= nil then
        infoText = notice .. "\n\n" .. infoText
    end
    info.setText(infoText)
    layout.addView(info)

    local nameField = EditText(this)
    nameField.setHint(T("Nama asli pengguna", "User's real name"))
    nameField.setContentDescription(T("Nama asli pengguna", "User's real name"))
    nameField.setInputType(InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_CAP_WORDS)
    nameField.setText(nameText or "")
    layout.addView(nameField)

    local codeField = EditText(this)
    codeField.setHint(T("Kode aktivasi pro dari pengembang", "Pro activation code from the developer"))
    codeField.setContentDescription(T("Kode aktivasi pro dari pengembang", "Pro activation code from the developer"))
    codeField.setInputType(InputType.TYPE_CLASS_TEXT)
    codeField.setText(codeText or "")
    layout.addView(codeField)

    local scroll = ScrollView(this)
    scroll.addView(layout)

    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Aktivasi fitur pro", "Pro feature activation"))
    builder.setView(scroll)

    builder.setPositiveButton(T("Aktifkan", "Activate"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            local name = khusus.gate.cleanName(nameField.getText())
            local code = khusus.gate.codeText(codeField.getText())
            dialog.dismiss()
            local currentDevice = khusus.pro.deviceId()
            local problem = nil
            if currentDevice == nil then
                problem = T("ID perangkat tidak terbaca, sehingga aktivasi pro tidak bisa dilanjutkan di perangkat ini.", "The device ID could not be read, so pro activation cannot continue on this device.")
            elseif not khusus.gate.validName(name) then
                problem = T("Nama tidak valid. Isi dengan nama asli sepanjang tiga sampai enam puluh karakter, hanya huruf, spasi, titik, apostrof, atau tanda hubung.", "The name is not valid. Enter your real name with three to sixty characters, using only letters, spaces, periods, apostrophes, or hyphens.")
            elseif code == "" then
                problem = T("Kode aktivasi belum diisi. Klik Minta aktivasi untuk meminta kode ke pengembang.", "The activation code is empty. Click Request activation to ask the developer for a code.")
            elseif code ~= khusus.pro.code(name, currentDevice) then
                problem = T("Kode aktivasi tidak sesuai dengan nama dan perangkat ini. Pastikan nama sama dengan yang Anda kirim ke pengembang dan kode dipakai di perangkat yang sama.", "The activation code does not match this name and device. Make sure the name is the same as the one you sent to the developer and the code is used on the same device.")
            end
            if problem ~= nil then
                khusus.pro.showForm(name, code, problem)
                service.speak(problem)
                return
            end
            if not khusus.pro.activate(name, code) then
                local failed = T("Aktivasi pro gagal disimpan. Silakan coba lagi.", "Pro activation could not be saved. Please try again.")
                khusus.pro.showForm(name, code, failed)
                service.speak(failed)
            end
        end
    })

    builder.setNeutralButton(T("Minta aktivasi", "Request activation"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            local name = khusus.gate.cleanName(nameField.getText())
            local code = khusus.gate.codeText(codeField.getText())
            dialog.dismiss()
            local currentDevice = khusus.pro.deviceId()
            local problem = nil
            if currentDevice == nil then
                problem = T("ID perangkat tidak terbaca, sehingga aktivasi pro tidak bisa diminta dari perangkat ini.", "The device ID could not be read, so pro activation cannot be requested from this device.")
            elseif not khusus.gate.validName(name) then
                problem = T("Isi nama dulu dengan nama asli tanpa angka dan simbol, lalu klik Minta aktivasi.", "Fill in the name first with your real name without numbers or symbols, then click Request activation.")
            end
            if problem ~= nil then
                khusus.pro.showForm(name, code, problem)
                service.speak(problem)
                return
            end
            pcall(function()
                getPrefs().edit().putString("pro_nama_draf", name).apply()
            end)
            local message = T("Assalamualaikum, saya minta aktivasi fitur pro ", "Hello, I would like to request pro feature activation for ") .. extensionName .. ".\n" .. T("Nama: ", "Name: ") .. name .. "\n" .. T("ID perangkat: ", "Device ID: ") .. currentDevice
            khusus.gate.open("https://wa.me/" .. khusus.gate.whatsappNumber .. "?text=" .. khusus.urlEncode(message), T("WhatsApp gagal dibuka. Hubungi pengembang di nomor ", "WhatsApp could not be opened. Contact the developer at number ") .. khusus.gate.whatsappDisplay)
        end
    })

    builder.setNegativeButton(T("Tutup", "Close"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
        end
    })
    presentDialog(builder)
end

function khusus.openMainSettings(announce)
    if not khusus.gate.require() then
        return
    end
    khusus.introToken = khusus.introToken + 1
    local token = khusus.introToken
    khusus.releaseIntro()
    if announce ~= nil then
        pcall(announce)
    end
    showMainSettings()
    pcall(function()
        khusus.handler.postDelayed(function()
            if token ~= khusus.introToken then
                return
            end
            pcall(function()
                local path = khusus.introFile()
                if path == nil then
                    return
                end
                local player = MediaPlayer()
                khusus.introPlayer = player
                player.setDataSource(path)
                player.setOnPreparedListener(MediaPlayer.OnPreparedListener{
                    onPrepared = function(mp)
                        if token == khusus.introToken and khusus.introPlayer == mp then
                            pcall(function() mp.start() end)
                        end
                    end
                })
                player.setOnCompletionListener(MediaPlayer.OnCompletionListener{
                    onCompletion = function(mp)
                        if khusus.introPlayer == mp then
                            khusus.releaseIntro()
                        end
                    end
                })
                player.setOnErrorListener(MediaPlayer.OnErrorListener{
                    onError = function(mp, what, extra)
                        if khusus.introPlayer == mp then
                            khusus.releaseIntro()
                        end
                        return true
                    end
                })
                player.prepareAsync()
            end)
        end, 120)
    end)
end

local function getEditText()
    local ok, editText = pcall(function()
        return service.getEditText()
    end)
    if ok and editText ~= nil then
        return editText
    end
    if getFlag("asisten_aktif", false) then
        if khusus.handleNoEditText() then
            return nil
        end
        khusus.openMainSettings(function()
            service.speak(T("Asisten aktif.", "Assistant is on."))
        end)
        return nil
    end
    khusus.openMainSettings(function()
        service.speak(T("Kotak edit tidak ditemukan.", "No edit box was found."))
    end)
    return nil
end

function khusus.resetService()
    khusus.serviceQueue = nil
    khusus.serviceIndex = 0
    khusus.activeService = nil
end

function khusus.alternativeServices()
    local queue = {}
    pcall(function()
        local defaultName = ""
        local stored = luajava.bindClass("android.provider.Settings$Secure").getString(this.getContentResolver(), "voice_recognition_service")
        if stored ~= nil then
            defaultName = tostring(stored)
        end
        local services = this.getPackageManager().queryIntentServices(Intent("android.speech.RecognitionService"), 0)
        for index = 0, services.size() - 1 do
            local serviceInfo = services.get(index).serviceInfo
            local component = ComponentName(serviceInfo.packageName, serviceInfo.name)
            local skip = false
            if defaultName ~= "" then
                skip = tostring(component.flattenToString()) == defaultName
            else
                skip = tostring(serviceInfo.packageName) == "com.google.android.googlequicksearchbox"
            end
            if not skip then
                queue[#queue + 1] = component
            end
        end
    end)
    return queue
end

function khusus.advanceService()
    if khusus.offlineOnly() then
        return false
    end
    if khusus.serviceQueue == nil then
        khusus.serviceQueue = khusus.alternativeServices()
        khusus.serviceIndex = 0
    end
    local nextIndex = khusus.serviceIndex + 1
    if nextIndex > #khusus.serviceQueue then
        return false
    end
    khusus.serviceIndex = nextIndex
    khusus.activeService = khusus.serviceQueue[nextIndex]
    return true
end

local function createRecognizer()
    while true do
        local component = khusus.activeService
        local created, recognizer = pcall(function()
            if component ~= nil then
                return SpeechRecognizer.createSpeechRecognizer(this, component)
            end
            return SpeechRecognizer.createSpeechRecognizer(this)
        end)
        if created and recognizer ~= nil then
            return recognizer
        end
        if component == nil or not khusus.advanceService() then
            return nil
        end
    end
end

function kill()
    khusus.introToken = khusus.introToken + 1
    khusus.releaseIntro()
    khusus.stopReadAloud()
    settingsExit.release()
    if speechRecognizer ~= nil then
        local recognizer = speechRecognizer
        speechRecognizer = nil
        pcall(function()
            recognizer.cancel()
        end)
        pcall(function()
            recognizer.destroy()
        end)
    end
    khusus.noiseOff()
    return true
end

local function release(recognizer)
    if speechRecognizer == recognizer then
        kill()
    end
end

local function launchRecognizer(recognizer, listener, intent, onFailure)
    local function launch()
        if speechRecognizer ~= recognizer then
            return
        end
        khusus.noiseOn()
        local started = pcall(function()
            recognizer.setRecognitionListener(listener)
            recognizer.startListening(intent)
        end)
        if not started then
            release(recognizer)
            onFailure()
        end
    end
    local scheduled = pcall(function()
        khusus.handler.postDelayed(launch, khusus.launchDelayMs)
    end)
    if not scheduled then
        launch()
    end
end

function khusus.isTrigger(text)
    local spoken = khusus.normalizeSpoken(text)
    local core = khusus.stripTrailing(khusus.stripLeading(spoken, khusus.commandLeading), khusus.commandTrailing)
    return khusus.isExactTrigger(khusus.squeeze(core))
end

khusus.stats = {
    dataKey = "statistik_harian",
    totalKey = "statistik_total",
    enabledKey = "pengingat_dikte",
    goalKey = "target_harian",
    keepDays = 120,
    goalOptions = { 0, 250, 500, 1000, 2000, 5000 },
    milestones = { 100, 250, 500, 1000, 1500, 2000, 3000, 5000, 7500, 10000, 15000, 20000 }
}

khusus.stats.voiceTriggers = pickLogic({
    ["statistik dikte"] = true,
    ["statistik dikte saya"] = true,
    ["laporan dikte"] = true,
    ["laporan dikte hari ini"] = true,
    ["berapa kata hari ini"] = true,
    ["berapa banyak kata hari ini"] = true
}, {
    ["dictation stats"] = true,
    ["dictation statistics"] = true,
    ["dictation report"] = true,
    ["how many words today"] = true
})

function khusus.stats.toDays(key)
    if type(key) ~= "number" then
        return nil
    end
    local year = math.floor(key / 10000)
    local month = math.floor(key / 100) % 100
    local day = key % 100
    if year < 2000 or year > 2999 or month < 1 or month > 12 or day < 1 or day > 31 then
        return nil
    end
    if month <= 2 then
        year = year - 1
    end
    local era = math.floor(year / 400)
    local yearOfEra = year - era * 400
    local shifted = (month + 9) % 12
    local dayOfYear = math.floor((153 * shifted + 2) / 5) + day - 1
    local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
    return era * 146097 + dayOfEra - 719468
end

function khusus.stats.fromDays(days)
    local shifted = days + 719468
    local era = math.floor(shifted / 146097)
    local dayOfEra = shifted - era * 146097
    local yearOfEra = math.floor((dayOfEra - math.floor(dayOfEra / 1460) + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365)
    local year = yearOfEra + era * 400
    local dayOfYear = dayOfEra - (365 * yearOfEra + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
    local monthIndex = math.floor((5 * dayOfYear + 2) / 153)
    local day = dayOfYear - math.floor((153 * monthIndex + 2) / 5) + 1
    local month = monthIndex + 3
    if monthIndex >= 10 then
        month = monthIndex - 9
    end
    if month <= 2 then
        year = year + 1
    end
    return year * 10000 + month * 100 + day
end

function khusus.stats.validKey(key)
    local days = khusus.stats.toDays(key)
    return days ~= nil and khusus.stats.fromDays(days) == key
end

function khusus.stats.clock()
    local ok, key = pcall(function()
        local now = os.date("*t", os.time())
        return now.year * 10000 + now.month * 100 + now.day
    end)
    if ok and type(key) == "number" and khusus.stats.validKey(key) then
        return key
    end
    return nil
end

function khusus.stats.shiftDay(key, offset)
    local days = khusus.stats.toDays(key)
    if days == nil then
        return nil
    end
    return khusus.stats.fromDays(days + offset)
end

function khusus.stats.countWords(text)
    local count = 0
    for token in tostring(text or ""):gmatch("%S+") do
        if token:find("[%w\128-\255]") ~= nil then
            count = count + 1
        end
    end
    return count
end

function khusus.stats.format(value)
    local number = math.floor((tonumber(value) or 0) + 0.5)
    if number < 0 then
        number = 0
    end
    local separator = ","
    if uiIndonesian then
        separator = "."
    end
    local digits = string.format("%d", number)
    local formatted = digits:reverse():gsub("(%d%d%d)", "%1" .. separator):reverse()
    if formatted:sub(1, 1) == separator then
        formatted = formatted:sub(2)
    end
    return formatted
end

function khusus.stats.wordsText(count)
    local text = khusus.stats.format(count)
    if uiIndonesian then
        return text .. " kata"
    end
    if math.floor(count) == 1 then
        return text .. " word"
    end
    return text .. " words"
end

function khusus.stats.sessionsText(count)
    local text = khusus.stats.format(count)
    if uiIndonesian then
        return text .. " kali dikte"
    end
    if math.floor(count) == 1 then
        return text .. " dictation"
    end
    return text .. " dictations"
end

function khusus.stats.daysText(count)
    local text = khusus.stats.format(count)
    if uiIndonesian then
        return text .. " hari"
    end
    if math.floor(count) == 1 then
        return text .. " day"
    end
    return text .. " days"
end

function khusus.stats.dateText(key)
    if not khusus.stats.validKey(key) then
        return ""
    end
    local year = math.floor(key / 10000)
    local month = math.floor(key / 100) % 100
    local day = key % 100
    return string.format("%02d-%02d-%04d", day, month, year)
end

function khusus.stats.load()
    local entries = {}
    local map = {}
    local totals = { words = 0, sessions = 0, best = 0, since = 0 }
    local rawDays = ""
    local rawTotals = ""
    pcall(function()
        local prefs = getPrefs()
        rawDays = tostring(prefs.getString(khusus.stats.dataKey, "") or "")
        rawTotals = tostring(prefs.getString(khusus.stats.totalKey, "") or "")
    end)
    for line in rawDays:gmatch("[^\n]+") do
        local key, words, sessions = line:match("^(%d%d%d%d%d%d%d%d),(%d+),(%d+)$")
        if key ~= nil then
            key = tonumber(key)
            if khusus.stats.validKey(key) and map[key] == nil then
                local entry = { key = key, words = tonumber(words), sessions = tonumber(sessions) }
                entries[#entries + 1] = entry
                map[key] = entry
            end
        end
    end
    table.sort(entries, function(a, b)
        return a.key < b.key
    end)
    local words, sessions, best, since = rawTotals:match("^(%d+)|(%d+)|(%d+)|(%d+)$")
    if words ~= nil then
        totals.words = tonumber(words)
        totals.sessions = tonumber(sessions)
        totals.best = tonumber(best)
        totals.since = tonumber(since)
    end
    return entries, map, totals
end

function khusus.stats.save(entries, totals)
    local lines = {}
    for _, item in ipairs(entries) do
        lines[#lines + 1] = string.format("%08d,%d,%d", item.key, item.words, item.sessions)
    end
    local summary = string.format("%d|%d|%d|%08d", totals.words, totals.sessions, totals.best, totals.since)
    local saved = pcall(function()
        getPrefs().edit().putString(khusus.stats.dataKey, table.concat(lines, "\n")).putString(khusus.stats.totalKey, summary).apply()
    end)
    return saved
end

function khusus.stats.reset()
    return pcall(function()
        getPrefs().edit().remove(khusus.stats.dataKey).remove(khusus.stats.totalKey).apply()
    end)
end

function khusus.stats.goalIndex()
    local index = 1
    pcall(function()
        index = math.floor(getPrefs().getInt(khusus.stats.goalKey, 1))
    end)
    if index < 1 or index > #khusus.stats.goalOptions then
        index = 1
    end
    return index
end

function khusus.stats.goalWords()
    return khusus.stats.goalOptions[khusus.stats.goalIndex()]
end

function khusus.stats.streak(map, today)
    local current = today
    if map[today] == nil or map[today].words < 1 then
        current = khusus.stats.shiftDay(today, -1)
    end
    local count = 0
    while current ~= nil and count < 1000 do
        local entry = map[current]
        if entry == nil or entry.words < 1 then
            break
        end
        count = count + 1
        current = khusus.stats.shiftDay(current, -1)
    end
    return count
end

function khusus.stats.record(text)
    local words = khusus.stats.countWords(text)
    if words < 1 then
        return nil
    end
    local today = khusus.stats.clock()
    if today == nil then
        return nil
    end
    local entries, map, totals = khusus.stats.load()
    local entry = map[today]
    local firstOfDay = entry == nil
    local before = 0
    if entry == nil then
        entry = { key = today, words = 0, sessions = 0 }
        entries[#entries + 1] = entry
        map[today] = entry
    else
        before = entry.words
    end
    local priorBest = totals.best
    for _, item in ipairs(entries) do
        if item.key < today and item.words > priorBest then
            priorBest = item.words
        end
    end
    entry.words = entry.words + words
    entry.sessions = entry.sessions + 1
    totals.words = totals.words + words
    totals.sessions = totals.sessions + 1
    totals.best = priorBest
    if totals.since == 0 or today < totals.since then
        totals.since = today
    end
    table.sort(entries, function(a, b)
        return a.key < b.key
    end)
    while #entries > khusus.stats.keepDays do
        local removed = table.remove(entries, 1)
        map[removed.key] = nil
    end
    khusus.stats.save(entries, totals)
    local yesterday = 0
    local yesterdayEntry = map[khusus.stats.shiftDay(today, -1)]
    if yesterdayEntry ~= nil then
        yesterday = yesterdayEntry.words
    end
    return {
        added = words,
        before = before,
        after = entry.words,
        sessions = entry.sessions,
        firstOfDay = firstOfDay,
        yesterday = yesterday,
        streak = khusus.stats.streak(map, today),
        priorBest = priorBest
    }
end

function khusus.stats.crossedMilestone(before, after)
    local crossed = nil
    for _, value in ipairs(khusus.stats.milestones) do
        if before < value and value <= after then
            crossed = value
        end
    end
    local last = khusus.stats.milestones[#khusus.stats.milestones]
    if after > last then
        local higher = math.floor(after / 10000)
        if higher > math.floor(before / 10000) then
            crossed = higher * 10000
        end
    end
    return crossed
end

function khusus.stats.announcement(info)
    local stats = khusus.stats
    local parts = {}
    if info.firstOfDay and info.yesterday > 0 then
        local greeting = T("Selamat datang kembali. Kemarin Anda mendikte ", "Welcome back. Yesterday you dictated ") .. stats.wordsText(info.yesterday) .. "."
        if info.streak >= 2 then
            greeting = greeting .. T(" Rentetan dikte Anda ", " Your dictation streak is ") .. stats.daysText(info.streak) .. T(" berturut-turut.", " in a row.")
        end
        parts[#parts + 1] = greeting
    end
    local goal = stats.goalWords()
    if goal > 0 and info.before < goal and info.after >= goal then
        parts[#parts + 1] = T("Target harian ", "Daily goal of ") .. stats.wordsText(goal) .. T(" tercapai. Hari ini Anda mendikte ", " reached. Today you have dictated ") .. stats.wordsText(info.after) .. T(". Mantap!", ". Great job!")
    elseif info.priorBest > 0 and info.before <= info.priorBest and info.after > info.priorBest then
        parts[#parts + 1] = T("Rekor baru! Hari ini Anda mendikte ", "New record! Today you have dictated ") .. stats.wordsText(info.after) .. T(", terbanyak sejauh ini.", ", your most so far.")
    else
        local milestone = stats.crossedMilestone(info.before, info.after)
        if milestone ~= nil then
            local endings = {
                T("Lancar sekali!", "Smooth going!"),
                T("Terus semangat!", "Keep it up!"),
                T("Suara Anda produktif hari ini.", "Your voice is productive today."),
                T("Jari-jari boleh istirahat.", "Your fingers can take a break.")
            }
            local ending = endings[(info.after + info.sessions) % #endings + 1]
            parts[#parts + 1] = T("Hari ini Anda sudah mendikte ", "Today you have dictated ") .. stats.wordsText(info.after) .. ". " .. ending
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

function khusus.stats.announce(message, speakLength)
    local delay = 1200
    if speakLength ~= nil and speakLength > 0 then
        delay = 1700 + speakLength * 90
    end
    delay = math.floor(delay)
    local hold = System.currentTimeMillis() + delay + 1200 + #message * 90
    if khusus.autoTypeHold == nil or hold > khusus.autoTypeHold then
        khusus.autoTypeHold = hold
    end
    local generation = khusus.generation
    local scheduled = pcall(function()
        khusus.handler.postDelayed(function()
            if generation ~= khusus.generation or speechRecognizer ~= nil then
                return
            end
            pcall(function()
                service.speak(message)
            end)
        end, delay)
    end)
    return scheduled
end

function khusus.stats.afterDictation(source, speakLength)
    local recorded, info = pcall(khusus.stats.record, source)
    if not recorded or info == nil then
        return
    end
    if not getFlag(khusus.stats.enabledKey, true) then
        return
    end
    local built, message = pcall(khusus.stats.announcement, info)
    if built and type(message) == "string" and message ~= "" then
        khusus.stats.announce(message, speakLength)
    end
end

function khusus.stats.snapshot()
    local stats = khusus.stats
    local entries, map, totals = stats.load()
    local snap = {
        today = 0,
        sessions = 0,
        yesterday = 0,
        week = 0,
        average = 0,
        best = totals.best,
        totalWords = totals.words,
        totalSessions = totals.sessions,
        since = totals.since,
        streak = 0,
        goal = stats.goalWords(),
        hasData = totals.words > 0 or #entries > 0
    }
    local today = stats.clock()
    if today == nil then
        return snap
    end
    local entry = map[today]
    if entry ~= nil then
        snap.today = entry.words
        snap.sessions = entry.sessions
    end
    local yesterdayEntry = map[stats.shiftDay(today, -1)]
    if yesterdayEntry ~= nil then
        snap.yesterday = yesterdayEntry.words
    end
    for offset = 0, 6 do
        local item = map[stats.shiftDay(today, -offset)]
        if item ~= nil then
            snap.week = snap.week + item.words
        end
    end
    snap.average = math.floor(snap.week / 7 + 0.5)
    for _, item in ipairs(entries) do
        if item.words > snap.best then
            snap.best = item.words
        end
    end
    snap.streak = stats.streak(map, today)
    return snap
end

function khusus.stats.report()
    local stats = khusus.stats
    local snap = stats.snapshot()
    if not snap.hasData then
        return T("Belum ada data dikte. Mulailah mendikte, lalu statistik akan muncul di sini.", "No dictation data yet. Start dictating and your statistics will appear here.")
    end
    local lines = {}
    if snap.today > 0 then
        lines[#lines + 1] = T("Hari ini: ", "Today: ") .. stats.wordsText(snap.today) .. T(" dalam ", " in ") .. stats.sessionsText(snap.sessions)
    else
        lines[#lines + 1] = T("Hari ini: belum mendikte", "Today: no dictation yet")
    end
    lines[#lines + 1] = T("Kemarin: ", "Yesterday: ") .. stats.wordsText(snap.yesterday)
    lines[#lines + 1] = T("7 hari terakhir: ", "Last 7 days: ") .. stats.wordsText(snap.week) .. T(", rata-rata ", ", average ") .. stats.wordsText(snap.average) .. T(" per hari", " per day")
    lines[#lines + 1] = T("Rekor harian: ", "Daily record: ") .. stats.wordsText(snap.best)
    if snap.streak > 0 then
        lines[#lines + 1] = T("Rentetan: ", "Streak: ") .. stats.daysText(snap.streak) .. T(" berturut-turut", " in a row")
    end
    if snap.goal > 0 then
        if snap.today >= snap.goal then
            lines[#lines + 1] = T("Target harian ", "Daily goal of ") .. stats.wordsText(snap.goal) .. T(": tercapai", ": reached")
        else
            lines[#lines + 1] = T("Target harian ", "Daily goal of ") .. stats.wordsText(snap.goal) .. T(": sisa ", ": ") .. stats.wordsText(snap.goal - snap.today) .. T(" lagi", " to go")
        end
    end
    local since = stats.dateText(snap.since)
    if since ~= "" then
        lines[#lines + 1] = T("Total sejak ", "Total since ") .. since .. ": " .. stats.wordsText(snap.totalWords) .. T(" dalam ", " in ") .. stats.sessionsText(snap.totalSessions)
    end
    if snap.today == 0 and snap.streak > 0 then
        lines[#lines + 1] = T("Dikte hari ini untuk melanjutkan rentetan Anda.", "Dictate today to keep your streak going.")
    end
    return table.concat(lines, "\n")
end

function khusus.stats.spoken()
    local stats = khusus.stats
    local ok, snap = pcall(stats.snapshot)
    if not ok or snap == nil or not snap.hasData then
        return T("Belum ada data dikte. Mulailah mendikte, lalu tanyakan lagi.", "No dictation data yet. Start dictating, then ask again.")
    end
    local parts = {}
    if snap.today > 0 then
        parts[#parts + 1] = T("Hari ini Anda mendikte ", "Today you have dictated ") .. stats.wordsText(snap.today) .. T(" dalam ", " in ") .. stats.sessionsText(snap.sessions) .. "."
    else
        parts[#parts + 1] = T("Hari ini Anda belum mendikte.", "You have not dictated yet today.")
    end
    if snap.yesterday > 0 then
        parts[#parts + 1] = T("Kemarin ", "Yesterday ") .. stats.wordsText(snap.yesterday) .. "."
    end
    if snap.week > 0 then
        parts[#parts + 1] = T("Tujuh hari terakhir ", "Last seven days ") .. stats.wordsText(snap.week) .. "."
    end
    if snap.goal > 0 then
        if snap.today >= snap.goal then
            parts[#parts + 1] = T("Target harian tercapai.", "Daily goal reached.")
        else
            parts[#parts + 1] = T("Sisa ", "") .. stats.wordsText(snap.goal - snap.today) .. T(" menuju target harian.", " to go for your daily goal.")
        end
    end
    if snap.streak > 0 then
        parts[#parts + 1] = T("Rentetan ", "Streak ") .. stats.daysText(snap.streak) .. "."
        if snap.today == 0 then
            parts[#parts + 1] = T("Dikte hari ini untuk melanjutkannya.", "Dictate today to keep it going.")
        end
    end
    return table.concat(parts, " ")
end

function khusus.stats.matchVoice(list)
    if list == nil then
        return false
    end
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        if khusus.stats.voiceTriggers[spoken] == true then
            return true
        end
    end
    return false
end

function khusus.stats.goalLabel()
    local goal = khusus.stats.goalWords()
    if goal == 0 then
        return T("Nonaktif", "Off")
    end
    return khusus.stats.wordsText(goal)
end

function khusus.stats.showReport()
    local ok, text = pcall(khusus.stats.report)
    if not ok or type(text) ~= "string" then
        text = T("Statistik gagal dibaca.", "The statistics could not be read.")
    end
    khusus.showNotice(T("Statistik dikte", "Dictation statistics"), text, khusus.stats.showMenu)
end

function khusus.stats.showGoalChoice()
    local names = {}
    for index, value in ipairs(khusus.stats.goalOptions) do
        if value == 0 then
            names[index] = T("Nonaktif", "Off")
        else
            names[index] = khusus.stats.wordsText(value)
        end
    end
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Target harian dikte", "Daily dictation goal"))
    builder.setSingleChoiceItems(names, khusus.stats.goalIndex() - 1, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            getPrefs().edit().putInt(khusus.stats.goalKey, which + 1).apply()
            dialog.dismiss()
            local value = khusus.stats.goalOptions[which + 1]
            if value == 0 then
                service.speak(T("Target harian dinonaktifkan.", "Daily goal turned off."))
            else
                service.speak(T("Target harian ", "Daily goal ") .. khusus.stats.wordsText(value) .. ".")
            end
            khusus.stats.showMenu()
        end
    })
    builder.setNegativeButton(T("Kembali", "Back"), DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            dialog.dismiss()
            khusus.stats.showMenu()
        end
    })
    presentDialog(builder)
end

function khusus.stats.confirmReset()
    khusus.showConfirm(T("Reset statistik dikte", "Reset dictation statistics"), T("Semua catatan statistik dikte akan dihapus. Pengaturan lain tidak berubah. Lanjutkan?", "All dictation statistics will be deleted. Other settings are unchanged. Continue?"), function()
        khusus.stats.reset()
        service.speak(T("Statistik dikte direset.", "Dictation statistics reset."))
        khusus.stats.showMenu()
    end, function()
        khusus.stats.showMenu()
    end)
end

function khusus.stats.showMenu()
    local items = {
        T("Lihat statistik dikte", "View dictation statistics"),
        T("Pengingat dikte: ", "Dictation reminders: ") .. stateText(getFlag(khusus.stats.enabledKey, true)),
        T("Target harian: ", "Daily goal: ") .. khusus.stats.goalLabel(),
        T("Reset statistik dikte", "Reset dictation statistics"),
        T("Kembali", "Back")
    }
    local builder = AlertDialog.Builder(this)
    builder.setTitle(T("Statistik dan pengingat dikte", "Dictation statistics and reminders"))
    builder.setItems(items, DialogInterface.OnClickListener{
        onClick = function(dialog, which)
            feedbackUI()
            if which == 0 then
                khusus.stats.showReport()
            elseif which == 1 then
                toggleFlag(khusus.stats.enabledKey, true)
                khusus.stats.showMenu()
            elseif which == 2 then
                khusus.stats.showGoalChoice()
            elseif which == 3 then
                khusus.stats.confirmReset()
            else
                dialog.dismiss()
                showBjrSettings()
            end
        end
    })
    presentDialog(builder)
end

khusus.waktu = {}
khusus.waktu.pasaranNames = { "Legi", "Pahing", "Pon", "Wage", "Kliwon" }
khusus.waktu.dayNames = pickLogic(
    { "Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu" },
    { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" })
khusus.waktu.monthNames = pickLogic(
    { "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember" },
    { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" })
khusus.waktu.hijriMonths = pickLogic(
    { "Muharam", "Safar", "Rabiulawal", "Rabiulakhir", "Jumadilawal", "Jumadilakhir", "Rajab", "Syakban", "Ramadan", "Syawal", "Zulkaidah", "Zulhijah" },
    { "Muharram", "Safar", "Rabi al-awwal", "Rabi al-thani", "Jumada al-awwal", "Jumada al-thani", "Rajab", "Shaban", "Ramadan", "Shawwal", "Dhu al-Qadah", "Dhu al-Hijjah" })
khusus.waktu.ones = { [0] = "nol", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan", "sepuluh", "sebelas" }
khusus.waktu.triggers = pickLogic({
    ["jam berapa sekarang"] = "jam",
    ["sekarang jam berapa"] = "jam",
    ["pukul berapa sekarang"] = "jam",
    ["jam berapa"] = "jam",
    ["hari apa hari ini"] = "hari",
    ["hari apa sekarang"] = "hari",
    ["sekarang hari apa"] = "hari",
    ["hari apa"] = "hari",
    ["tanggal berapa hari ini"] = "tanggal",
    ["tanggal berapa sekarang"] = "tanggal",
    ["sekarang tanggal berapa"] = "tanggal",
    ["tanggal berapa"] = "tanggal",
    ["pasaran apa hari ini"] = "pasaran",
    ["hari pasaran hari ini"] = "pasaran",
    ["pasaran hari ini"] = "pasaran",
    ["hari pasaran"] = "pasaran",
    ["pasaran apa"] = "pasaran",
    ["tanggal hijriah"] = "hijriah",
    ["tanggal hijriyah"] = "hijriah",
    ["tanggal hijriah hari ini"] = "hijriah",
    ["tanggal hijriyah hari ini"] = "hijriah",
    ["tanggal hijriah berapa"] = "hijriah",
    ["tanggal hijriyah berapa"] = "hijriah",
    ["tanggal berapa hijriah"] = "hijriah",
    ["tanggal berapa hijriyah"] = "hijriah",
    ["hijriah hari ini"] = "hijriah",
    ["hijriyah hari ini"] = "hijriah",
    ["hijriah sekarang"] = "hijriah",
    ["hijriyah sekarang"] = "hijriah",
    ["hijriah berapa"] = "hijriah",
    ["hijriyah berapa"] = "hijriah",
    ["kalender hijriah"] = "hijriah",
    ["kalender hijriyah"] = "hijriah",
    ["tanggal islam"] = "hijriah",
    ["tanggal islam hari ini"] = "hijriah",
    ["hari dan tanggal"] = "lengkap",
    ["hari tanggal"] = "lengkap",
    ["hari dan tanggal hari ini"] = "lengkap",
    ["hari tanggal hari ini"] = "lengkap",
    ["hari dan tanggal sekarang"] = "lengkap",
    ["tanggal lengkap"] = "lengkap",
    ["tanggal lengkap hari ini"] = "lengkap",
    ["hari dan tanggal hijriah"] = "lengkap",
    ["hari dan tanggal hijriyah"] = "lengkap",
    ["hari tanggal dan hijriah"] = "lengkap",
    ["hari tanggal dan hijriyah"] = "lengkap",
    ["tanggal masehi dan hijriah"] = "lengkap",
    ["tanggal masehi dan hijriyah"] = "lengkap",
    ["jam dan tanggal"] = "semua",
    ["tanggal dan jam"] = "semua",
    ["waktu dan tanggal"] = "semua",
    ["jam hari dan tanggal"] = "semua",
    ["jam hari tanggal"] = "semua",
    ["waktu lengkap"] = "semua",
    ["waktu lengkap hari ini"] = "semua",
    ["info lengkap"] = "semua",
    ["umumkan waktu"] = "semua",
    ["sebutkan waktu lengkap"] = "semua",
    ["jam hari pasaran hijriah"] = "semua",
    ["jam hari pasaran hijriyah"] = "semua",
    ["jam hari pasaran dan hijriah"] = "semua",
    ["jam hari pasaran dan hijriyah"] = "semua",
    ["jam hari pasaran tanggal hijriah"] = "semua",
    ["jam hari pasaran tanggal hijriyah"] = "semua",
    ["jam hari pasaran kalender hijriah"] = "semua",
    ["jam hari pasaran kalender hijriyah"] = "semua",
    ["jam hari pasaran dan kalender hijriah"] = "semua",
    ["jam hari pasaran dan kalender hijriyah"] = "semua",
    ["info waktu"] = "semua",
    ["info tanggal"] = "semua"
}, {
    ["what time is it"] = "jam",
    ["what is the time"] = "jam",
    ["what time is it now"] = "jam",
    ["what day is it"] = "hari",
    ["what day is it today"] = "hari",
    ["what is the date"] = "tanggal",
    ["what is the date today"] = "tanggal",
    ["what is today s date"] = "tanggal",
    ["market day today"] = "pasaran",
    ["javanese market day"] = "pasaran",
    ["hijri date"] = "hijriah",
    ["what is the hijri date"] = "hijriah",
    ["what is today s hijri date"] = "hijriah",
    ["islamic date"] = "hijriah",
    ["what is the islamic date"] = "hijriah",
    ["day and date"] = "lengkap",
    ["full date"] = "lengkap",
    ["what is the full date"] = "lengkap",
    ["full time and date"] = "semua",
    ["complete time and date"] = "semua",
    ["announce the time"] = "semua",
    ["date and time"] = "semua",
    ["time and date"] = "semua"
})

khusus.waktu.fuzzyWords = {
    jam = "jam",
    pukul = "jam",
    waktu = "jam",
    hari = "hari",
    tanggal = "tanggal",
    pasaran = "pasaran",
    hijriah = "hijri",
    hijriyah = "hijri",
    hijriyyah = "hijri",
    hijri = "hijri",
    islam = "hijri"
}
khusus.waktu.fillerWords = {
    dan = true,
    serta = true,
    dengan = true,
    beserta = true,
    plus = true,
    lengkap = true,
    ini = true,
    sekarang = true,
    apa = true,
    berapa = true,
    sebutkan = true,
    umumkan = true,
    tolong = true,
    info = true,
    masehi = true,
    kalender = true
}

function khusus.waktu.fuzzy(spoken)
    if not logicIndonesian then
        return nil
    end
    local seen = {}
    local count = 0
    for word in spoken:gmatch("%S+") do
        local concept = khusus.waktu.fuzzyWords[word]
        if concept ~= nil then
            if not seen[concept] then
                seen[concept] = true
                count = count + 1
            end
        elseif khusus.waktu.fillerWords[word] ~= true then
            return nil
        end
    end
    if count < 2 then
        return nil
    end
    if seen.jam then
        return "semua"
    end
    if seen.hijri then
        if seen.hari or seen.pasaran then
            return "lengkap"
        end
        return "hijriah"
    end
    if seen.tanggal then
        return "lengkap"
    end
    return "pasaran"
end

function khusus.waktu.match(list)
    if list == nil then
        return nil
    end
    for i = 0, list.size() - 1 do
        local spoken = tostring(list.get(i)):lower():gsub("[^%w%s]", " ")
        spoken = khusus.trim(spoken:gsub("%s+", " "))
        local kind = khusus.waktu.triggers[spoken]
        if kind == nil then
            kind = khusus.waktu.fuzzy(spoken)
        end
        if kind ~= nil then
            return kind
        end
    end
    return nil
end

function khusus.waktu.words(number)
    local ones = khusus.waktu.ones
    if number <= 11 then
        return ones[number]
    end
    if number < 20 then
        return ones[number - 10] .. " belas"
    end
    local text = ones[math.floor(number / 10)] .. " puluh"
    if number % 10 > 0 then
        text = text .. " " .. ones[number % 10]
    end
    return text
end

function khusus.waktu.hijriCorrection()
    local value = 0
    pcall(function()
        value = math.floor(tonumber(getPrefs().getInt("koreksi_hijriah", 0)) or 0)
    end)
    if value > 1 then
        value = 1
    elseif value < -1 then
        value = -1
    end
    return value
end

function khusus.waktu.correctionLabel()
    local value = khusus.waktu.hijriCorrection()
    if value > 0 then
        return T("maju satu hari", "plus one day")
    elseif value < 0 then
        return T("mundur satu hari", "minus one day")
    end
    return T("tanpa koreksi", "no correction")
end

function khusus.waktu.cycleCorrection()
    local value = khusus.waktu.hijriCorrection() + 1
    if value > 1 then
        value = -1
    end
    getPrefs().edit().putInt("koreksi_hijriah", value).apply()
    return value
end

function khusus.waktu.hijri(count)
    local number = count + 2440588 - 1948440 + khusus.waktu.hijriCorrection()
    local cycles = math.floor(number / 10631)
    local rest = number - cycles * 10631
    local yearIndex = 1
    while true do
        local length = 354
        if (11 * yearIndex + 14) % 30 < 11 then
            length = 355
        end
        if rest < length then
            break
        end
        rest = rest - length
        yearIndex = yearIndex + 1
    end
    local month = 1
    while month < 12 do
        local monthLength = 29
        if month % 2 == 1 then
            monthLength = 30
        end
        if rest < monthLength then
            break
        end
        rest = rest - monthLength
        month = month + 1
    end
    return math.floor(rest + 1), month, math.floor(cycles * 30 + yearIndex)
end

function khusus.waktu.snapshot()
    local d = os.date("*t", os.time())
    local info = {
        hour = d.hour,
        min = d.min,
        day = d.day,
        month = d.month,
        year = d.year,
        dayName = khusus.waktu.dayNames[d.wday],
        monthName = khusus.waktu.monthNames[d.month]
    }
    local count = khusus.stats.toDays(d.year * 10000 + d.month * 100 + d.day)
    if count ~= nil then
        info.pasaran = khusus.waktu.pasaranNames[(count + 3) % 5 + 1]
        local done, hijriDay, hijriMonth, hijriYear = pcall(khusus.waktu.hijri, count)
        if done and hijriDay ~= nil and hijriMonth ~= nil and hijriYear ~= nil then
            info.hijriDay = hijriDay
            info.hijriMonth = hijriMonth
            info.hijriYear = hijriYear
        end
    end
    return info
end

function khusus.waktu.dayPasaran(info)
    if info.pasaran ~= nil then
        return info.dayName .. " " .. info.pasaran
    end
    return info.dayName
end

function khusus.waktu.dateText(info)
    return info.day .. " " .. info.monthName .. " " .. info.year
end

function khusus.waktu.hijriText(info, forSpeech)
    if info.hijriYear == nil then
        return nil
    end
    local text = string.format("%d %s %d", info.hijriDay, khusus.waktu.hijriMonths[info.hijriMonth], info.hijriYear)
    if forSpeech then
        return text .. T(" Hijriah", " Hijri")
    end
    return text .. T(" H", " AH")
end

function khusus.waktu.spokenTime(info)
    local hour12 = info.hour % 12
    if hour12 == 0 then
        hour12 = 12
    end
    if not logicIndonesian then
        local suffix = "AM"
        if info.hour >= 12 then
            suffix = "PM"
        end
        return string.format("%d:%02d %s", hour12, info.min, suffix)
    end
    local part = "malam"
    if info.hour >= 1 and info.hour <= 3 then
        part = "dini hari"
    elseif info.hour >= 4 and info.hour <= 10 then
        part = "pagi"
    elseif info.hour >= 11 and info.hour <= 14 then
        part = "siang"
    elseif info.hour >= 15 and info.hour <= 17 then
        part = "sore"
    end
    if info.min == 0 then
        return "pukul " .. khusus.waktu.words(hour12) .. " " .. part
    end
    return "pukul " .. khusus.waktu.words(hour12) .. " lewat " .. khusus.waktu.words(info.min) .. " menit " .. part
end

function khusus.waktu.written(kind, info)
    local clock = string.format(T("%02d.%02d", "%02d:%02d"), info.hour, info.min)
    if kind == "jam" then
        return clock
    elseif kind == "hari" then
        return info.dayName
    elseif kind == "tanggal" then
        return khusus.waktu.dateText(info)
    elseif kind == "pasaran" then
        return khusus.waktu.dayPasaran(info)
    elseif kind == "hijriah" then
        return khusus.waktu.hijriText(info, false)
    end
    local text = khusus.waktu.dayPasaran(info) .. ", " .. khusus.waktu.dateText(info)
    local hijri = khusus.waktu.hijriText(info, false)
    if hijri ~= nil then
        text = text .. " / " .. hijri
    end
    if kind == "semua" then
        text = T("Pukul ", "At ") .. clock .. ", " .. text
    end
    return text
end

function khusus.waktu.spoken(kind, info)
    if kind == "jam" then
        return T("Sekarang ", "It is ") .. khusus.waktu.spokenTime(info) .. "."
    elseif kind == "hari" then
        return T("Hari ini ", "Today is ") .. info.dayName .. "."
    elseif kind == "tanggal" then
        return T("Hari ini tanggal ", "Today's date is ") .. khusus.waktu.dateText(info) .. "."
    elseif kind == "pasaran" then
        return T("Hari ini ", "Today is ") .. khusus.waktu.dayPasaran(info) .. "."
    elseif kind == "hijriah" then
        return T("Hari ini tanggal ", "Today's Hijri date is ") .. khusus.waktu.hijriText(info, true) .. "."
    end
    local text = T("Hari ini ", "Today is ") .. khusus.waktu.dayPasaran(info) .. ", " .. T("tanggal ", "") .. khusus.waktu.dateText(info)
    if kind == "semua" then
        text = T("Sekarang ", "It is ") .. khusus.waktu.spokenTime(info) .. ", " .. T("hari ", "") .. khusus.waktu.dayPasaran(info) .. ", " .. T("tanggal ", "") .. khusus.waktu.dateText(info)
    end
    local hijri = khusus.waktu.hijriText(info, true)
    if hijri ~= nil then
        text = text .. ", " .. T("bertepatan dengan ", "which is ") .. hijri
    end
    return text .. "."
end

function khusus.waktu.run(kind)
    local ok, info = pcall(khusus.waktu.snapshot)
    if not ok or info == nil then
        khusus.speakAfterMicrophone(T("Waktu gagal dibaca.", "The time could not be read."))
        return
    end
    if kind == "hijriah" and info.hijriYear == nil then
        khusus.speakAfterMicrophone(T("Tanggal hijriah gagal dihitung.", "The Hijri date could not be calculated."))
        return
    end
    local found, node = pcall(function()
        return service.getEditText()
    end)
    local usable = found and node ~= nil
    if usable then
        local isPassword = false
        pcall(function()
            isPassword = node.isPassword() == true
        end)
        if isPassword then
            usable = false
        end
    end
    if not usable then
        khusus.speakAfterMicrophone(khusus.waktu.spoken(kind, info))
        return
    end
    local text = khusus.waktu.written(kind, info)
    if getFlag("spasi_setelah_teks", false) then
        text = text .. " "
    end
    if getFlag("baris_baru") then
        text = text .. "\n"
    end
    khusus.writeInsert(text, 3, function(inserted)
        if inserted then
            khusus.lastInserted = text
            khusus.speakAfterMicrophone(T("Ditulis.", "Written."))
        elseif khusus.copyToClipboard(text) then
            khusus.speakAfterMicrophone(T("Pesan tersalin ke papan klip.", "Message copied to the clipboard."))
        else
            khusus.speakAfterMicrophone(T("Teks gagal dimasukkan.", "The text could not be inserted."))
        end
    end)
end

function khusus.listenForTrigger(isRetry)
    kill()
    if not isRetry then
        khusus.triggerQuietRetries = 0
        khusus.resetService()
    end

    local recognizer = createRecognizer()
    if recognizer == nil then
        return false
    end
    speechRecognizer = recognizer

    local function conclude(matched, translateTarget, command, heard, failed, clean, correct, autoType, read, write, statsAsk, waktuAsk)
        if speechRecognizer ~= recognizer then
            return
        end
        release(recognizer)
        if translateTarget ~= nil then
            khusus.lastAssistantTime = nil
            khusus.translateByFocus(translateTarget)
        elseif clean then
            khusus.lastAssistantTime = nil
            khusus.speakAfterMicrophone(khusus.cleanByVoice())
        elseif correct then
            khusus.lastAssistantTime = nil
            khusus.correctByFocus()
        elseif autoType ~= nil then
            khusus.lastAssistantTime = nil
            khusus.autoTypeCommand(autoType)
        elseif read then
            khusus.lastAssistantTime = nil
            khusus.readByVoice()
        elseif write ~= nil then
            khusus.lastAssistantTime = nil
            khusus.writeByVoice(write)
        elseif statsAsk then
            khusus.lastAssistantTime = nil
            khusus.speakAfterMicrophone(khusus.stats.spoken())
        elseif waktuAsk ~= nil then
            khusus.lastAssistantTime = nil
            khusus.waktu.run(waktuAsk)
        elseif matched then
            khusus.lastAssistantTime = nil
            khusus.openMainSettings(function()
                khusus.speakAfterMicrophone(T("Asisten aktif.", "Assistant is on."))
            end)
        elseif command ~= nil then
            khusus.lastAssistantTime = nil
            khusus.runCommand(command)
        elseif failed then
            khusus.recognitionFailed()
        elseif heard then
            local message = T("Perintah tidak dikenali. Ucapkan buka lalu nama aplikasi, atau buka pengaturan.", "Command not recognized. Say open followed by an app name, or open settings.")
            if khusus.appCount ~= nil and khusus.appCount == 0 then
                message = T("Perintah tidak dikenali. Daftar aplikasi tidak terbaca di HP ini, tetapi perintah buka pengaturan telepon tetap bisa dipakai.", "Command not recognized. The app list cannot be read on this phone, but the open phone settings command still works.")
            end
            khusus.speakAfterMicrophone(message)
        else
            khusus.speakAfterMicrophone(T("Tidak ada suara terdengar.", "No sound was heard."))
        end
    end

    local function containsTrigger(list)
        if list == nil then
            return false
        end
        for i = 0, list.size() - 1 do
            if khusus.isTrigger(tostring(list.get(i))) then
                return true
            end
        end
        return false
    end

    local triggerListener = RecognitionListener{
        onReadyForSpeech = function(params)
        end,
        onBeginningOfSpeech = function()
        end,
        onBufferReceived = function(buffer)
        end,
        onEvent = function(eventType, params)
        end,
        onRmsChanged = function(rms)
        end,
        onEndOfSpeech = function()
        end,
        onPartialResults = function(partialResults)
        end,
        onResults = function(results)
            local list = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            local translateTarget = nil
            local command = nil
            local heard = false
            local matched = containsTrigger(list)
            local clean = false
            local correct = false
            local autoType = nil
            local read = false
            local write = nil
            local statsAsk = false
            local waktuAsk = nil
            if list ~= nil then
                heard = list.size() > 0
                translateTarget = khusus.matchTranslateText(list)
                clean = khusus.matchClean(list)
                correct = khusus.matchCorrect(list)
                autoType = khusus.matchAutoType(list)
                read = khusus.matchRead(list)
                write = khusus.matchWrite(list)
                statsAsk = khusus.stats.matchVoice(list)
                waktuAsk = khusus.waktu.match(list)
                if translateTarget == nil and not matched and not clean and not correct and autoType == nil and not read and write == nil and not statsAsk and waktuAsk == nil then
                    command = khusus.matchCommand(list)
                end
            end
            conclude(matched, translateTarget, command, heard, false, clean, correct, autoType, read, write, statsAsk, waktuAsk)
        end,
        onError = function(errorCode)
            if khusus.fallbackErrors[errorCode] and speechRecognizer == recognizer and khusus.advanceService() then
                release(recognizer)
                khusus.handler.postDelayed(function()
                    if speechRecognizer == nil and not khusus.listenForTrigger(true) then
                        khusus.recognitionFailed()
                    end
                end, 150)
                return
            end
            if (errorCode == 6 or errorCode == 7) and speechRecognizer == recognizer and khusus.triggerQuietRetries < khusus.quietMaxRetries then
                khusus.triggerQuietRetries = khusus.triggerQuietRetries + 1
                release(recognizer)
                khusus.handler.postDelayed(function()
                    if speechRecognizer == nil and not khusus.listenForTrigger(true) then
                        khusus.recognitionFailed()
                    end
                end, 150)
                return
            end
            if errorCode == 6 or errorCode == 7 then
                conclude(false, nil, nil, false, false)
            else
                conclude(false, nil, nil, false, true)
            end
        end
    }

    local triggerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    triggerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    triggerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, getLanguageTag())
    triggerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, this.getPackageName())
    triggerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
    khusus.engineExtras(triggerIntent)

    launchRecognizer(recognizer, triggerListener, triggerIntent, function()
        khusus.recognitionFailed()
    end)
    return true
end

local function startListening(isRetry)
    if not khusus.gate.require() then
        return true
    end
    if not isRetry and khusus.sendVoiceMessage() then
        return true
    end
    if not isRetry then
        khusus.entryFocus = nil
        if getFlag("asisten_aktif", false) then
            khusus.entryFocus = khusus.readingFocus()
        end
    end
    local editText = getEditText()

    if editText == nil then
        return false
    end

    profileLayer.values = khusus.profileLayerFor(editText)

    kill()

    if not isRetry then
        khusus.quietRetries = 0
        khusus.busyRetries = 0
        khusus.resetService()
    end

    local pauses = {}
    local currentPause = nil
    local lastPartialTime = 0
    local lastWordCount = 0
    local rmsSeen = false
    local smoothed = 0
    local noiseFloor = 0
    local voicePeak = 0
    local inVoice = false
    local voiceRun = 0
    local lastTick = 0
    local lastVoiceTime = 0
    local voicedMs = 0
    local voicedSincePause = 0
    local lastPause = nil
    local settleUntil = 0
    local heardVoice = false
    local endSignaled = false
    local resultHandled = false
    local lastSpeechTime = 0
    local lastPartialText = ""
    local stopRequested = false
    local function signalEnd()
        if endSignaled then
            return
        end
        endSignaled = true
        if not khusus.autoTypeRunning() then
            signalVibration("end")
        end
    end
    local pauseEnabled = getFlag("jeda_napas")
    local pauseIndex = getPauseIndex()
    local level = pauseLevels[pauseIndex]
    local commaGap = level[1]
    local periodGap = level[2]
    local resumeMs = pauseResumeLevels[pauseIndex]
    local voiceRatio = pauseVoiceRatio[pauseIndex]
    local voiceFloor = pauseVoiceFloor[pauseIndex]
    local minVoiced = pauseMinVoiced[pauseIndex]
    local endSilence = pauseEndSilence[pauseIndex]
    voiceRatio = voiceRatio * khusus.whisperRatio
    voiceFloor = voiceFloor * khusus.whisperFloor
    commaGap = math.floor(commaGap * 1.15)
    periodGap = math.floor(periodGap * 1.15)
    minVoiced = math.floor(minVoiced * khusus.whisperVoiced)
    resumeMs = math.floor(resumeMs * 0.8)
    local noiseEndMs = khusus.minCompleteSilenceMs
    if pauseEnabled and endSilence > noiseEndMs then
        noiseEndMs = endSilence
    end
    if noiseEndMs < 3000 then
        noiseEndMs = 3000
    end
    noiseEndMs = noiseEndMs + khusus.noiseEndExtraMs

    local recognizer = createRecognizer()
    if recognizer == nil then
        service.speak(T("Pengenalan suara gagal disiapkan.", "Speech recognition could not be prepared."))
        return false
    end
    speechRecognizer = recognizer

    local speechSeen = false
    local function retryQuiet()
        if khusus.quietRetries >= khusus.quietMaxRetries or speechRecognizer ~= recognizer then
            return false
        end
        khusus.quietRetries = khusus.quietRetries + 1
        endSignaled = true
        release(recognizer)
        khusus.handler.postDelayed(function()
            if speechRecognizer == nil then
                startListening(true)
            end
        end, 150)
        return true
    end

    local speechListener = RecognitionListener{
        onReadyForSpeech = function(params)
            if not isRetry then
                signalVibration("start")
            end
        end,
        onBeginningOfSpeech = function()
        end,
        onBufferReceived = function(buffer)
        end,
        onEvent = function(eventType, params)
        end,
        onRmsChanged = function(rms)
            local now = System.currentTimeMillis()
            if not rmsSeen then
                rmsSeen = true
                smoothed = rms
                noiseFloor = rms
                voicePeak = rms
                lastTick = now
            end
            smoothed = smoothed + (rms - smoothed) * 0.4
            if smoothed < noiseFloor then
                noiseFloor = noiseFloor + (smoothed - noiseFloor) * 0.5
            else
                noiseFloor = noiseFloor + (smoothed - noiseFloor) * 0.004
            end
            if smoothed > voicePeak then
                voicePeak = smoothed
            else
                voicePeak = voicePeak - (voicePeak - noiseFloor) * 0.01
            end
            local margin = (voicePeak - noiseFloor) * voiceRatio
            if margin < voiceFloor then
                margin = voiceFloor
            end
            if inVoice then
                margin = margin * 0.6
            end
            local elapsed = now - lastTick
            lastTick = now
            if elapsed > 250 then
                elapsed = 250
            end
            inVoice = smoothed > noiseFloor + margin
            if inVoice then
                voiceRun = voiceRun + elapsed
            else
                voiceRun = 0
            end
            if inVoice and voiceRun >= khusus.noiseSpikeMs then
                voicedMs = voicedMs + elapsed
                voicedSincePause = voicedSincePause + elapsed
                lastVoiceTime = now
                heardVoice = true
                if voiceRun >= resumeMs and currentPause ~= nil then
                    lastPause = currentPause
                    settleUntil = now + pauseAnchorSettleMs
                    currentPause = nil
                end
            else
                if heardVoice and pauseEnabled then
                    local silence = now - lastVoiceTime
                    local mark = nil
                    if silence >= periodGap then
                        mark = "."
                    elseif silence >= commaGap then
                        mark = ","
                    end
                    if mark ~= nil then
                        if currentPause == nil then
                            if voicedSincePause >= minVoiced then
                                currentPause = { voiced = voicedMs, mark = mark, anchor = lastWordCount }
                                pauses[#pauses + 1] = currentPause
                                voicedSincePause = 0
                            end
                        elseif mark == "." then
                            currentPause.mark = "."
                        end
                    end
                end
            end
            if heardVoice and speechSeen and not stopRequested then
                local lastActive = lastVoiceTime
                if lastSpeechTime > lastActive then
                    lastActive = lastSpeechTime
                end
                if now - lastActive >= noiseEndMs then
                    stopRequested = true
                    pcall(function()
                        if speechRecognizer == recognizer then
                            recognizer.stopListening()
                        end
                    end)
                end
            end
        end,
        onEndOfSpeech = function()
            if not speechSeen and khusus.quietRetries < khusus.quietMaxRetries then
                return
            end
            signalEnd()
        end,
        onPartialResults = function(partialResults)
            local partial = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if partial == nil or partial.size() == 0 then
                return
            end
            local count = #splitWords(partial.get(0))
            if count > 0 then
                speechSeen = true
                local partialText = tostring(partial.get(0))
                if partialText ~= lastPartialText then
                    lastPartialText = partialText
                    lastSpeechTime = System.currentTimeMillis()
                end
            end
            if not pauseEnabled then
                return
            end
            local now = System.currentTimeMillis()
            if currentPause ~= nil then
                currentPause.anchor = count
            elseif lastPause ~= nil and now <= settleUntil and lastPause.anchor ~= nil and count == lastPause.anchor + 1 then
                lastPause.anchor = count
            end
            if not heardVoice and lastWordCount > 0 and count > lastWordCount and count - lastWordCount <= pausePartialBurst then
                local gap = now - lastPartialTime - pausePartialLatency
                local mark = nil
                if gap >= periodGap then
                    mark = "."
                elseif gap >= commaGap then
                    mark = ","
                end
                if mark ~= nil then
                    pauses[#pauses + 1] = { index = lastWordCount, voiced = 0, mark = mark }
                end
            end
            lastPartialTime = now
            lastWordCount = count
        end,
        onResults = function(results)
            if resultHandled then
                signalEnd()
                return
            end
            local candidates = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            local recognizedText = nil
            if candidates ~= nil then
                for index = 0, candidates.size() - 1 do
                    local candidate = candidates.get(index)
                    if candidate ~= nil then
                        local candidateText = tostring(candidate)
                        if candidateText:match("^%s*$") == nil then
                            recognizedText = khusus.trim(candidateText)
                            break
                        end
                    end
                end
            end
            if recognizedText == nil then
                resultHandled = true
                if not retryQuiet() then
                    signalEnd()
                    release(recognizer)
                end
                return
            end
            signalEnd()
            resultHandled = true
            local dictatedSource = recognizedText

            if getFlag("asisten_aktif", false) then
                local deleteMode = khusus.matchDelete(candidates)
                if deleteMode ~= nil then
                    release(recognizer)
                    khusus.speakAfterMicrophone(khusus.deleteInFocused(deleteMode))
                    return
                end
                if khusus.matchUndo(candidates) then
                    release(recognizer)
                    khusus.speakAfterMicrophone(khusus.undoDelete())
                    return
                end
                local autoTypeAction = khusus.matchAutoType(candidates)
                if autoTypeAction ~= nil then
                    release(recognizer)
                    khusus.autoTypeCommand(autoTypeAction)
                    return
                end
                if khusus.matchRead(candidates) then
                    release(recognizer)
                    khusus.readByVoice()
                    return
                end
                if khusus.stats.matchVoice(candidates) then
                    release(recognizer)
                    khusus.speakAfterMicrophone(khusus.stats.spoken())
                    return
                end
                local waktuKind = khusus.waktu.match(candidates)
                if waktuKind ~= nil then
                    release(recognizer)
                    khusus.waktu.run(waktuKind)
                    return
                end
                local writeEntry = khusus.matchWrite(candidates)
                if writeEntry ~= nil then
                    release(recognizer)
                    khusus.writeByVoice(writeEntry)
                    return
                end
                if khusus.matchClean(candidates) then
                    release(recognizer)
                    khusus.speakAfterMicrophone(khusus.cleanByVoice())
                    return
                end
                if khusus.matchCorrect(candidates) then
                    release(recognizer)
                    khusus.correctByFocus()
                    return
                end
                local translateTarget = khusus.matchTranslateText(candidates)
                if translateTarget ~= nil then
                    release(recognizer)
                    khusus.translateByFocus(translateTarget)
                    return
                end
                local assistantCommand = khusus.matchEditCommand(candidates)
                if assistantCommand ~= nil then
                    release(recognizer)
                    khusus.lastAssistantTime = nil
                    khusus.runCommand(assistantCommand)
                    return
                end
            end

            local function processText(source)
                local autoCapital = getFlag("kapital_otomatis")
                local useAutoMarks = getFlag("tanda_baca_otomatis", false)
                local macroText, macroHit = khusus.applyMacro(source)
                if macroHit then
                    return macroText, true
                end

                local text = source
                local formatting = logicIndonesian and getFlag("asisten_aktif", false)
                if pauseEnabled or useAutoMarks then
                    text = khusus.safeStage(khusus.markText, text, pauseEnabled, useAutoMarks, pauses, voicedMs, pauseIndex, formatting)
                end

                if getFlag("bersihkan_isian", true) then
                    text = khusus.safeStage(khusus.cleanFillers, text)
                end

                if getFlag("asisten_aktif", false) then
                    text = khusus.safeStage(khusus.applySpokenMarks, text)
                end

                text = khusus.safeStage(khusus.correctSpelling, text)
                text = khusus.safeStage(khusus.correctEnglish, text)
                text = khusus.safeStage(refinePunctuation, text)
                text = khusus.safeStage(substituteWords, text)
                text = khusus.safeStage(khusus.applyDictionary, text)

                if logicIndonesian then
                    if getFlag("asisten_aktif", false) then
                        text = khusus.safeStage(khusus.spokenAddresses, text)
                    end
                    text = text:gsub("\n", " \1 ")
                    text = khusus.safeStage(khusus.phoneNumber, text)
                    text = khusus.safeStage(khusus.rupiah, text)
                    text = text:gsub(" \1 ", "\n")
                end

                if autoCapital then
                    text = khusus.safeStage(capitalizeFirstWord, text)
                    text = khusus.safeStage(capitalizeAfterPeriod, text)
                end
                return text, false
            end

            local spellingSource = nil
            local spellingTriggered = false
            local sandiCalled = false
            local sandiLower = false
            local ejaanActive = getFlag("ejaan_rapi", false)
            if getFlag("asisten_aktif", false) then
                local sandiRemainder, sandiFound, sandiSmall = khusus.extractSandiTrigger(recognizedText)
                if sandiFound then
                    sandiCalled = true
                    sandiLower = sandiSmall
                    spellingSource = sandiRemainder
                end
            end
            if not sandiCalled and (ejaanActive or getFlag("asisten_aktif", false)) then
                local ejaanRemainder, ejaanCalled = khusus.extractEjaanTrigger(recognizedText)
                if ejaanCalled then
                    spellingTriggered = true
                    spellingSource = ejaanRemainder
                elseif ejaanActive then
                    spellingSource = recognizedText
                end
            end
            local spelledOut = spellingSource ~= nil

            local macroMatched = false
            if spelledOut then
                local spellText = spellingSource
                local spellMarks = getFlag("tanda_baca_otomatis", false)
                if (pauseEnabled or spellMarks) and not sandiCalled then
                    local markedText = khusus.safeStage(khusus.markText, recognizedText, pauseEnabled, spellMarks, pauses, voicedMs, pauseIndex)
                    if spellingTriggered then
                        local markedRemainder, markedCalled = khusus.extractEjaanTrigger(markedText)
                        if markedCalled then
                            spellText = markedRemainder
                        end
                    else
                        spellText = markedText
                    end
                end
                recognizedText = khusus.safeStage(khusus.ejaan, spellText)
                if sandiLower then
                    recognizedText = recognizedText:lower()
                end
                if getFlag("kapital_otomatis") and not sandiCalled then
                    recognizedText = khusus.safeStage(capitalizeFirstWord, recognizedText)
                    recognizedText = khusus.safeStage(capitalizeAfterPeriod, recognizedText)
                end
            else
                local processedOk, processedText, processedMacro = pcall(processText, recognizedText)
                if processedOk and type(processedText) == "string" then
                    recognizedText = processedText
                    macroMatched = processedMacro == true
                end
            end

            local triggerSpec = nil
            local styleTriggered = false
            local jakselTriggered = false
            local gagapTriggered = false
            local cadelTriggered = false
            local betawiTriggered = false
            local tionghoaTriggered = false
            local islamiTriggered = false
            local buntetTriggered = false
            local gaulTriggered = false
            local lucuTriggered = false
            local santriTriggered = false
            local robotTriggered = false
            local lebayTriggered = false
            local ngapakTriggered = false
            local alayTriggered = false
            local caseMode = nil
            if not macroMatched and not spelledOut and getFlag("asisten_aktif", false) then
                local remainder, spec = khusus.extractLanguageTrigger(recognizedText)
                if spec ~= nil then
                    triggerSpec = spec
                    recognizedText = remainder
                else
                    local styleRemainder, styleCalled = khusus.extractStyleTrigger(recognizedText)
                    if styleCalled then
                        styleTriggered = true
                        recognizedText = styleRemainder
                        if getFlag("kapital_otomatis") then
                            recognizedText = khusus.capitalizeFirst(recognizedText)
                        end
                    else
                        local jakselRemainder, jakselCalled = khusus.extractJakselTrigger(recognizedText)
                        if jakselCalled then
                            jakselTriggered = true
                            recognizedText = jakselRemainder
                            if getFlag("kapital_otomatis") then
                                recognizedText = khusus.capitalizeFirst(recognizedText)
                            end
                        else
                            local gagapRemainder, gagapCalled = khusus.extractGagapTrigger(recognizedText)
                            if gagapCalled then
                                gagapTriggered = true
                                recognizedText = gagapRemainder
                                if getFlag("kapital_otomatis") then
                                    recognizedText = khusus.capitalizeFirst(recognizedText)
                                end
                            else
                                local cadelRemainder, cadelCalled = khusus.extractCadelTrigger(recognizedText)
                                if cadelCalled then
                                    cadelTriggered = true
                                    recognizedText = cadelRemainder
                                    if getFlag("kapital_otomatis") then
                                        recognizedText = khusus.capitalizeFirst(recognizedText)
                                    end
                                else
                                    local betawiRemainder, betawiCalled = khusus.extractBetawiTrigger(recognizedText)
                                    if betawiCalled then
                                        betawiTriggered = true
                                        recognizedText = betawiRemainder
                                        if getFlag("kapital_otomatis") then
                                            recognizedText = khusus.capitalizeFirst(recognizedText)
                                        end
                                    else
                                        local tionghoaRemainder, tionghoaCalled = khusus.extractTionghoaTrigger(recognizedText)
                                        if tionghoaCalled then
                                            tionghoaTriggered = true
                                            recognizedText = tionghoaRemainder
                                            if getFlag("kapital_otomatis") then
                                                recognizedText = khusus.capitalizeFirst(recognizedText)
                                            end
                                        else
                                            local islamiRemainder, islamiCalled = khusus.extractIslamiTrigger(recognizedText)
                                            if islamiCalled then
                                                islamiTriggered = true
                                                recognizedText = islamiRemainder
                                                if getFlag("kapital_otomatis") then
                                                    recognizedText = khusus.capitalizeFirst(recognizedText)
                                                end
                                            else
                                                local buntetRemainder, buntetCalled = khusus.extractBuntetTrigger(recognizedText)
                                                if buntetCalled then
                                                    buntetTriggered = true
                                                    recognizedText = buntetRemainder
                                                    if getFlag("kapital_otomatis") then
                                                        recognizedText = khusus.capitalizeFirst(recognizedText)
                                                    end
                                                else
                                                    local gaulRemainder, gaulCalled = khusus.extractGaulTrigger(recognizedText)
                                                    if gaulCalled then
                                                        gaulTriggered = true
                                                        recognizedText = gaulRemainder
                                                        if getFlag("kapital_otomatis") then
                                                            recognizedText = khusus.capitalizeFirst(recognizedText)
                                                        end
                                                    else
                                                        local lucuRemainder, lucuCalled = khusus.extractLucuTrigger(recognizedText)
                                                        if lucuCalled then
                                                            lucuTriggered = true
                                                            recognizedText = lucuRemainder
                                                            if getFlag("kapital_otomatis") then
                                                                recognizedText = khusus.capitalizeFirst(recognizedText)
                                                            end
                                                        else
                                                            local santriRemainder, santriCalled = khusus.extractSantriTrigger(recognizedText)
                                                            if santriCalled then
                                                                santriTriggered = true
                                                                recognizedText = santriRemainder
                                                                if getFlag("kapital_otomatis") then
                                                                    recognizedText = khusus.capitalizeFirst(recognizedText)
                                                                end
                                                            else
                                                                local robotRemainder, robotCalled = khusus.extractRobotTrigger(recognizedText)
                                                                if robotCalled then
                                                                    robotTriggered = true
                                                                    recognizedText = robotRemainder
                                                                    if getFlag("kapital_otomatis") then
                                                                        recognizedText = khusus.capitalizeFirst(recognizedText)
                                                                    end
                                                                else
                                                                    local lebayRemainder, lebayCalled = khusus.extractLebayTrigger(recognizedText)
                                                                    if lebayCalled then
                                                                        lebayTriggered = true
                                                                        recognizedText = lebayRemainder
                                                                        if getFlag("kapital_otomatis") then
                                                                            recognizedText = khusus.capitalizeFirst(recognizedText)
                                                                        end
                                                                    else
                                                                        local ngapakRemainder, ngapakCalled = khusus.extractNgapakTrigger(recognizedText)
                                                                        if ngapakCalled then
                                                                            ngapakTriggered = true
                                                                            recognizedText = ngapakRemainder
                                                                            if getFlag("kapital_otomatis") then
                                                                                recognizedText = khusus.capitalizeFirst(recognizedText)
                                                                            end
                                                                        else
                                                                            local alayRemainder, alayCalled = khusus.extractAlayTrigger(recognizedText)
                                                                            if alayCalled then
                                                                                alayTriggered = true
                                                                                recognizedText = alayRemainder
                                                                                if getFlag("kapital_otomatis") then
                                                                                    recognizedText = khusus.capitalizeFirst(recognizedText)
                                                                                end
                                                                            else
                                                                                local caseRemainder, caseFound = khusus.extractCaseTrigger(recognizedText)
                                                                                if caseFound ~= nil then
                                                                                    caseMode = caseFound
                                                                                    recognizedText = caseRemainder
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local function deliver(finalText)
                if finalText == nil or finalText == "" then
                    return
                end
                finalText = khusus.applyCase(tostring(finalText), caseMode)
                local output = tostring(finalText)
                if not sandiCalled then
                    if getFlag("spasi_setelah_teks", false) and output:match("%s$") == nil then
                        output = output .. " "
                    end
                    if getFlag("baris_baru") and (macroMatched or output:sub(-1) ~= "\n") then
                        output = output .. "\n"
                    end
                end

                local function attempt()
                    local freshOk, freshEditText = pcall(function()
                        return service.getEditText()
                    end)
                    if freshOk and freshEditText ~= nil then
                        local freshInserted = pcall(function()
                            service.insertText(freshEditText, output)
                        end)
                        if freshInserted then
                            return true
                        end
                        return pcall(function()
                            service.insertText(editText, output)
                        end)
                    end
                    return false
                end

                local function finish(inserted)
                    if sandiCalled then
                        if inserted then
                            khusus.speakAfterMicrophone(T("Sandi dimasukkan.", "Password entered."))
                        else
                            khusus.speakAfterMicrophone(T("Sandi gagal dimasukkan. Pastikan kotak edit sedang fokus.", "The password could not be entered. Make sure an edit box is focused."))
                        end
                    elseif inserted then
                        khusus.lastInserted = output
                        local speakLength = 0
                        if getFlag("ucapkan_hasil") or khusus.autoTypeRunning() then
                            speakLength = #tostring(finalText)
                            khusus.speakAfterMicrophone(tostring(finalText))
                        end
                        khusus.stats.afterDictation(dictatedSource, speakLength)
                    elseif khusus.copyToClipboard(tostring(finalText)) then
                        khusus.speakAfterMicrophone(T("Pesan tersalin ke papan klip.", "Message copied to the clipboard."))
                        khusus.stats.afterDictation(dictatedSource, 32)
                    else
                        khusus.speakAfterMicrophone(T("Teks hasil dikte gagal dimasukkan.", "The dictation result could not be inserted."))
                    end
                end

                if attempt() then
                    finish(true)
                    return
                end
                local function retryInsert(remaining)
                    local scheduled = pcall(function()
                        khusus.handler.postDelayed(function()
                            local inserted = attempt()
                            if inserted or remaining <= 1 then
                                finish(inserted)
                            else
                                retryInsert(remaining - 1)
                            end
                        end, 250)
                    end)
                    if not scheduled then
                        finish(false)
                    end
                end
                retryInsert(3)
            end

            if recognizedText == "" then
                release(recognizer)
                if triggerSpec ~= nil then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah nama bahasa.", "Say a sentence after the language name."))
                elseif styleTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah singkatan umum.", "Say a sentence after common abbreviations."))
                elseif jakselTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah singkatan jaksel.", "Say a sentence after Jaksel abbreviations."))
                elseif gagapTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah gagap.", "Say a sentence after stutter style."))
                elseif cadelTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah cadel.", "Say a sentence after lisp style."))
                elseif betawiTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah betawi.", "Say a sentence after Betawi style."))
                elseif tionghoaTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah tionghoa.", "Say a sentence after the Tionghoa trigger."))
                elseif islamiTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah islami.", "Say a sentence after the Islami trigger."))
                elseif buntetTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah buntet.", "Say a sentence after the Buntet trigger."))
                elseif gaulTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah gaul.", "Say a sentence after the Gaul trigger."))
                elseif lucuTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah lucu.", "Say a sentence after the Lucu trigger."))
                elseif santriTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah santri.", "Say a sentence after the Santri trigger."))
                elseif robotTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah robot.", "Say a sentence after the Robot trigger."))
                elseif lebayTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah lebay.", "Say a sentence after the Lebay trigger."))
                elseif ngapakTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah ngapak.", "Say a sentence after the Ngapak trigger."))
                elseif alayTriggered then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah alay.", "Say a sentence after the Alay trigger."))
                elseif sandiCalled then
                    khusus.speakAfterMicrophone(T("Ucapkan huruf dan angka setelah sandi.", "Say letters and numbers after password."))
                elseif spelledOut then
                    khusus.speakAfterMicrophone(T("Ucapkan huruf setelah ejaan.", "Say letters after spelling."))
                elseif caseMode ~= nil then
                    khusus.speakAfterMicrophone(T("Ucapkan kalimat setelah perintah huruf.", "Say a sentence after the letter case command."))
                end
                return
            end

            release(recognizer)

            if triggerSpec ~= nil then
                khusus.translateTrigger(recognizedText, triggerSpec, deliver)
            elseif getFlag("terjemah_output", false) and not spelledOut and not khusus.offlineOnly() then
                khusus.translate(recognizedText, khusus.sourceLang(), khusus.targetLang(), deliver)
            else
                if not macroMatched and not spelledOut then
                    if gagapTriggered then
                        recognizedText = khusus.safeStage(khusus.stutter, recognizedText)
                    elseif cadelTriggered then
                        recognizedText = khusus.safeStage(khusus.cadel, recognizedText)
                    elseif betawiTriggered then
                        recognizedText = khusus.safeStage(khusus.betawi, recognizedText)
                    elseif tionghoaTriggered then
                        recognizedText = khusus.safeStage(khusus.tionghoa, recognizedText)
                    elseif islamiTriggered then
                        recognizedText = khusus.safeStage(khusus.islami, recognizedText)
                    elseif buntetTriggered then
                        recognizedText = khusus.safeStage(khusus.buntet, recognizedText)
                    elseif gaulTriggered then
                        recognizedText = khusus.safeStage(khusus.gaul, recognizedText)
                    elseif lucuTriggered then
                        recognizedText = khusus.safeStage(khusus.lucu, recognizedText)
                    elseif santriTriggered then
                        recognizedText = khusus.safeStage(khusus.santri, recognizedText)
                    elseif robotTriggered then
                        recognizedText = khusus.safeStage(khusus.robot, recognizedText)
                    elseif lebayTriggered then
                        recognizedText = khusus.safeStage(khusus.lebay, recognizedText)
                    elseif ngapakTriggered then
                        recognizedText = khusus.safeStage(khusus.ngapak, recognizedText)
                    elseif alayTriggered then
                        recognizedText = khusus.safeStage(khusus.alay, recognizedText)
                    elseif styleTriggered then
                        recognizedText = khusus.safeStage(khusus.abbreviate, recognizedText)
                    elseif jakselTriggered then
                        recognizedText = khusus.safeStage(khusus.abbreviateJaksel, recognizedText)
                    elseif getFlag("gaya_gagap", false) then
                        recognizedText = khusus.safeStage(khusus.stutter, recognizedText)
                    elseif getFlag("gaya_cadel", false) then
                        recognizedText = khusus.safeStage(khusus.cadel, recognizedText)
                    elseif getFlag("gaya_jaksel", false) then
                        recognizedText = khusus.safeStage(khusus.abbreviateJaksel, recognizedText)
                    elseif getFlag("gaya_singkatan", false) then
                        recognizedText = khusus.safeStage(khusus.abbreviate, recognizedText)
                    end
                end
                deliver(recognizedText)
            end
        end,
        onError = function(errorCode)
            if resultHandled then
                return
            end
            if (errorCode == 6 or errorCode == 7) and retryQuiet() then
                return
            end
            if (errorCode == 8 or errorCode == 10 or errorCode == 11) and not speechSeen and (khusus.busyRetries or 0) < 3 and speechRecognizer == recognizer then
                khusus.busyRetries = (khusus.busyRetries or 0) + 1
                endSignaled = true
                release(recognizer)
                khusus.handler.postDelayed(function()
                    if speechRecognizer == nil then
                        startListening(true)
                    end
                end, 200)
                return
            end
            if khusus.fallbackErrors[errorCode] and not speechSeen and speechRecognizer == recognizer and khusus.advanceService() then
                endSignaled = true
                release(recognizer)
                khusus.handler.postDelayed(function()
                    if speechRecognizer == nil then
                        startListening(true)
                    end
                end, 150)
                return
            end
            signalEnd()
            release(recognizer)
            local message = errorMessages[errorCode]
            if message ~= nil then
                khusus.autoTypeFail()
                khusus.speakAfterMicrophone(message)
            end
        end
    }

    local recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, getLanguageTag())
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, this.getPackageName())
    recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
    khusus.engineExtras(recognizerIntent)
    local completeSilence = 0
    local possiblySilence = 0
    if pauseEnabled then
        completeSilence = endSilence
        possiblySilence = math.floor(endSilence * 0.7)
    end
    if completeSilence < khusus.minCompleteSilenceMs then
        completeSilence = khusus.minCompleteSilenceMs
        possiblySilence = math.floor(khusus.minCompleteSilenceMs * 0.7)
    end
    if completeSilence < 3000 then
        completeSilence = 3000
    end
    if possiblySilence < 2000 then
        possiblySilence = 2000
    end
    pcall(function()
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, Long(800))
    end)
    if completeSilence > 0 then
        pcall(function()
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, Long(completeSilence))
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, Long(possiblySilence))
        end)
    end

    launchRecognizer(recognizer, speechListener, recognizerIntent, function()
        khusus.autoTypeFail()
        service.speak(T("Pengenalan suara gagal dimulai.", "Speech recognition could not be started."))
    end)

    return true
end

function khusus.autoTypeStart()
    local found, node = pcall(function()
        return service.getEditText()
    end)
    if not found or node == nil then
        khusus.speakAfterMicrophone(T("Tidak ada kotak edit yang fokus. Fokuskan kotak edit, jalankan ekstensi, lalu ucapkan ngetik otomatis.", "No edit box is focused. Focus an edit box, run the extension, then say auto typing."))
        return
    end
    local now = System.currentTimeMillis()
    local token = tostring(now)
    khusus.autoTypeToken = token
    khusus.autoTypeIdleSince = nil
    khusus.autoTypeBeatAt = now
    pcall(function()
        local editor = getPrefs().edit()
        editor.putBoolean(khusus.autoTypeActiveKey, true)
        editor.putString(khusus.autoTypeTokenKey, token)
        editor.putString(khusus.autoTypeBeatKey, tostring(now))
        editor.apply()
    end)
    khusus.speakAfterMicrophone(T("Ngetik otomatis aktif.", "Auto typing is on."))
    khusus.autoTypeSchedule(token)
end

function khusus.autoTypeCommand(action)
    if action == "stop" then
        local active = khusus.autoTypeStored()
        khusus.autoTypeStop()
        if active then
            khusus.speakAfterMicrophone(T("Ngetik otomatis dihentikan.", "Auto typing stopped."))
        else
            khusus.speakAfterMicrophone(T("Ngetik otomatis tidak sedang berjalan.", "Auto typing is not running."))
        end
        return
    end
    if khusus.autoTypeRunning() then
        khusus.speakAfterMicrophone(T("Ngetik otomatis sudah aktif.", "Auto typing is already on."))
        return
    end
    khusus.autoTypeStart()
end

function khusus.autoTypeSchedule(token)
    pcall(function()
        khusus.handler.postDelayed(function()
            khusus.autoTypeTick(token)
        end, khusus.autoTypeTickMs)
    end)
end

function khusus.autoTypeTick(token)
    if not khusus.autoTypeOwns(token) then
        return
    end
    if not getFlag("asisten_aktif", false) then
        khusus.autoTypeStop()
        return
    end
    local now = System.currentTimeMillis()
    khusus.autoTypeBeat(now)
    if speechRecognizer ~= nil then
        khusus.autoTypeIdleSince = nil
    elseif khusus.autoTypeIdleSince == nil then
        khusus.autoTypeIdleSince = now
    elseif now - khusus.autoTypeIdleSince >= khusus.autoTypeIdleMs and now >= khusus.autoTypeHold then
        khusus.autoTypeIdleSince = nil
        khusus.quietRetries = 0
        khusus.busyRetries = 0
        local started = false
        pcall(function()
            started = startListening(true) == true
        end)
        if not started then
            khusus.autoTypeStop()
            khusus.speakAfterMicrophone(T("Tidak ada kotak edit yang fokus. Ngetik otomatis dihentikan.", "No edit box is focused. Auto typing stopped."))
            return
        end
    end
    khusus.autoTypeSchedule(token)
end

function khusus.autoTypeEntry()
    local active, beat = khusus.autoTypeStored()
    if not active then
        return false
    end
    local fresh = System.currentTimeMillis() - beat <= khusus.autoTypeStaleMs
    khusus.autoTypeStop()
    if not fresh then
        return false
    end
    kill()
    khusus.speakAfterMicrophone(T("Ngetik otomatis dihentikan.", "Auto typing stopped."))
    return true
end

khusus.update = {
    versi = 1,
    alamat = "https://raw.githubusercontent.com/dangbjr445-oss/bjr_dang/main/",
    manifest = "versi.txt",
    jedaMs = 6 * 3600 * 1000,
    kunciCek = "update_cek_terakhir",
    kunciVersi = "update_versi"
}

function khusus.update.unduh(nama)
    local conn, reader
    local ok, status, body = pcall(function()
        conn = URL(khusus.update.alamat .. nama .. "?t=" .. tostring(System.currentTimeMillis())).openConnection()
        conn.setRequestMethod("GET")
        conn.setRequestProperty("User-Agent", khusus.userAgent)
        conn.setRequestProperty("Cache-Control", "no-cache")
        conn.setConnectTimeout(10000)
        conn.setReadTimeout(20000)
        local code = tonumber(conn.getResponseCode()) or -1
        if code ~= 200 then
            return code, ""
        end
        reader = BufferedReader(InputStreamReader(conn.getInputStream(), "UTF-8"))
        local lines = {}
        local line = reader.readLine()
        while line ~= nil do
            lines[#lines + 1] = tostring(line)
            line = reader.readLine()
        end
        return code, table.concat(lines, "\n") .. "\n"
    end)
    pcall(function() if reader then reader.close() end end)
    pcall(function() if conn then conn.disconnect() end end)
    if not ok or status ~= 200 or body == nil or body == "" then
        return nil
    end
    return body
end

function khusus.update.sha256(teks)
    local ok, hex = pcall(function()
        local digest = luajava.bindClass("java.security.MessageDigest").getInstance("SHA-256")
        local bytes = luajava.bindClass("java.lang.String")(teks).getBytes("UTF-8")
        local hasil = digest.digest(bytes)
        local out = {}
        for i = 0, hasil.length - 1 do
            out[#out + 1] = string.format("%02x", (tonumber(hasil[i]) + 256) % 256)
        end
        return table.concat(out)
    end)
    if ok then
        return hex
    end
    return nil
end

function khusus.update.baca(teks)
    local info = { berkas = {} }
    for baris in teks:gmatch("[^\r\n]+") do
        local k, v = baris:match("^%s*([^=%s]+)%s*=%s*(.-)%s*$")
        if k == "versi" then
            info.versi = tonumber(v)
        elseif k and k:find("^[%w_%-]+%.lua$") then
            info.berkas[#info.berkas + 1] = { nama = k, hash = (v ~= "" and v:lower() or nil) }
        end
    end
    return info
end

function khusus.update.folder()
    local ok, hasil = pcall(function()
        for _, direktori in ipairs(khusus.introDirectories()) do
            local berkas = File(direktori .. "/main.lua")
            if berkas.isFile() and berkas.canWrite() then
                return direktori
            end
        end
        return nil
    end)
    if ok then
        return hasil
    end
    return nil
end

function khusus.update.tulis(path, teks)
    local penulis = BufferedWriter(OutputStreamWriter(FileOutputStream(path), "UTF-8"))
    penulis.write(teks)
    penulis.close()
end

function khusus.update.pasang(folder, daftar)
    local selesai = {}
    local function batal()
        for _, item in ipairs(selesai) do
            pcall(function()
                File(item.path).delete()
                File(item.cadangan).renameTo(File(item.path))
            end)
        end
        for _, item in ipairs(daftar) do
            pcall(function() File(folder .. "/" .. item.nama .. ".baru").delete() end)
        end
    end
    for _, item in ipairs(daftar) do
        local ok = pcall(khusus.update.tulis, folder .. "/" .. item.nama .. ".baru", item.teks)
        if not ok then
            batal()
            return false
        end
    end
    for _, item in ipairs(daftar) do
        local path = folder .. "/" .. item.nama
        local cadangan = path .. ".bak"
        local baru = path .. ".baru"
        local ok = pcall(function()
            File(cadangan).delete()
            local lama = File(path)
            if lama.isFile() and not lama.renameTo(File(cadangan)) then
                error("cadangan gagal")
            end
            if not File(baru).renameTo(File(path)) then
                File(cadangan).renameTo(File(path))
                error("pasang gagal")
            end
        end)
        if not ok then
            batal()
            return false
        end
        selesai[#selesai + 1] = { path = path, cadangan = cadangan }
    end
    return true
end

function khusus.update.jalankan()
    local u = khusus.update
    if u.alamat:find("NAMA_PENGGUNA", 1, true) or u.alamat:find("NAMA_REPO", 1, true) then
        return
    end
    local prefs = getPrefs()
    local sekarang = System.currentTimeMillis()
    if sekarang - prefs.getLong(u.kunciCek, 0) < u.jedaMs then
        return
    end
    local teksManifest = u.unduh(u.manifest)
    if not teksManifest then
        return
    end
    prefs.edit().putLong(u.kunciCek, sekarang).apply()
    local info = u.baca(teksManifest)
    local terpasang = math.max(u.versi, prefs.getInt(u.kunciVersi, 0))
    if not info.versi or info.versi <= terpasang or #info.berkas == 0 then
        return
    end
    local folder = u.folder()
    if not folder then
        return
    end
    local compile = loadstring or load
    local daftar = {}
    for _, item in ipairs(info.berkas) do
        local teks = u.unduh(item.nama)
        if not teks then
            return
        end
        if item.hash and u.sha256(teks) ~= item.hash and u.sha256((teks:gsub("\n$", ""))) ~= item.hash then
            return
        end
        local dikompilasi = compile(teks, "=" .. item.nama)
        if not dikompilasi then
            return
        end
        daftar[#daftar + 1] = { nama = item.nama, teks = teks }
    end
    if not u.pasang(folder, daftar) then
        return
    end
    prefs.edit().putInt(u.kunciVersi, info.versi).apply()
    pcall(function()
        khusus.handler.post(function()
            khusus.speakAfterMicrophone(T("Pembaruan versi " .. tostring(info.versi) .. " terpasang. Aktif saat alat dibuka lagi.", "Update version " .. tostring(info.versi) .. " installed. It takes effect the next time the tool opens."))
        end)
    end)
end

function khusus.update.mulai()
    if khusus.offlineOnly() then
        return
    end
    pcall(function()
        Thread(function()
            pcall(khusus.update.jalankan)
        end).start()
    end)
end

if not khusus.gate.require() then
    return true
end

khusus.update.mulai()

if not getFlag("petunjuk_awal_dilihat", false) then
    getPrefs().edit().putBoolean("petunjuk_awal_dilihat", true).apply()
    if showGuideText(true) ~= nil then
        return true
    end
end

if khusus.autoTypeEntry() then
    return true
end

startListening()
return true
