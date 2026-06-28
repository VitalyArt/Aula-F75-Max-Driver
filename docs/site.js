const translations = {
  en: {
    metaDescription: "Aula F75 Max Driver is a native macOS utility for configuring the Epomaker x Aula F75 Max keyboard, display, RGB lighting, battery, and 2.4G mode.",
    ogDescription: "A polished native macOS driver for Aula F75 Max: display uploads, RGB, battery, Game Mode, and HID diagnostics.",
    navAria: "Primary navigation",
    navFeatures: "Features",
    navWorkflow: "Workflow",
    navInstall: "Install",
    languageLabel: "Language",
    heroEyebrow: "Native macOS utility",
    heroTitle: "Control Aula F75 Max without extra drivers.",
    heroText: "Configure the keyboard display, RGB lighting, battery status, response level, and Game Mode from one focused app for Apple Silicon Macs.",
    downloadDmg: "Download DMG",
    howToInstall: "How to install",
    heroFactsAria: "Key facts",
    mainScreenshotAlt: "Aula F75 Max Driver main window",
    batteryLabel: "Battery",
    introDisplay: "Upload images and GIFs to the keyboard display with fit, fill, and stretch modes.",
    introWireless: "Control battery, RGB lighting, response, sleep, and Game Mode through the receiver.",
    introHid: "Direct communication through macOS HID APIs without kernel extensions or libusb.",
    featuresEyebrow: "What's inside",
    featuresTitle: "Tools built specifically for the F75 Max.",
    featuresText: "The app separates wired operations from 2.4G settings, so it is clear which connection mode each task needs.",
    featureDisplayTitle: "Keyboard display",
    featureDisplayText: "Upload PNG, JPEG, GIF, BMP, TIFF, and WebP files to the 128 x 128 display. Animated GIFs keep their frame delays.",
    featureRgbTitle: "RGB and performance",
    featureRgbText: "Configure lighting mode, brightness, speed, direction, fixed color, response level, and sleep timeout.",
    featureBatteryTitle: "Battery and alerts",
    featureBatteryText: "Read battery percentage through the 2.4G receiver and get a local notification when it drops below 20%.",
    featureDiagnosticsTitle: "HID diagnostics",
    featureDiagnosticsText: "The endpoints panel shows transport, usage pages, and report sizes for quick connection and macOS permission checks.",
    workflowEyebrow: "Workflow",
    workflowTitle: "Two connections, two areas of responsibility.",
    workflowText: "USB-C is used for display tasks and clock sync. The 2.4G receiver is used for battery, RGB, response, sleep, and Game Mode.",
    workflowItemClock: "Sync the keyboard clock to local macOS time.",
    workflowItemReset: "Factory reset for display slots and configuration blocks used by this app.",
    workflowItemLogin: "Launch at Login and interface language selection.",
    workflowItemLocales: "Localizations: English, Russian, Spanish, Uzbek, Kazakh, Portuguese, Simplified Chinese.",
    detailsScreenshotAlt: "HID endpoint diagnostics and app settings",
    installEyebrow: "Install",
    installTitle: "Download the DMG or build locally.",
    installReadyTitle: "Ready-made build",
    installReadyText: "Open the latest GitHub Release, download the DMG, and move the app to Applications.",
    installReadyLink: "Open releases/latest",
    installBuildTitle: "Build from source",
    installBuildText: "Requires macOS 14+, an Apple Silicon Mac, and Xcode Command Line Tools.",
    installPermissionsTitle: "macOS permissions",
    installPermissionsText: "If HID commands do not run, grant Input Monitoring permission to the app and restart it.",
    ctaEyebrow: "Open source",
    ctaTitle: "A native driver you can inspect and build yourself.",
    sourceCode: "Source code",
    footerText: "macOS HID utility for Epomaker x Aula F75 Max"
  },
  ru: {
    metaDescription: "Aula F75 Max Driver - нативная macOS утилита для настройки клавиатуры Epomaker x Aula F75 Max, дисплея, RGB, батареи и режима 2.4G.",
    ogDescription: "Аккуратный нативный macOS-драйвер для Aula F75 Max: загрузка на экран, RGB, батарея, Game Mode и диагностика HID.",
    navAria: "Основная навигация",
    navFeatures: "Возможности",
    navWorkflow: "Сценарии",
    navInstall: "Установка",
    languageLabel: "Язык",
    heroEyebrow: "Нативная утилита для macOS",
    heroTitle: "Контроль Aula F75 Max без лишних драйверов.",
    heroText: "Настраивайте экран клавиатуры, RGB, батарею, отклик и Game Mode из одного аккуратного приложения для Apple Silicon Mac.",
    downloadDmg: "Скачать DMG",
    howToInstall: "Как установить",
    heroFactsAria: "Ключевые факты",
    mainScreenshotAlt: "Главное окно Aula F75 Max Driver",
    batteryLabel: "Батарея",
    introDisplay: "Загрузка изображений и GIF на экран клавиатуры с режимами fit, fill и stretch.",
    introWireless: "Управление батареей, RGB, откликом, сном и игровым режимом через приемник.",
    introHid: "Прямая работа через macOS HID APIs без kernel extensions и без libusb.",
    featuresEyebrow: "Что внутри",
    featuresTitle: "Инструменты, которые нужны именно для F75 Max.",
    featuresText: "Приложение разделяет проводные операции и 2.4G-настройки, чтобы было понятно, какой режим нужен для конкретной задачи.",
    featureDisplayTitle: "Экран клавиатуры",
    featureDisplayText: "Загружайте PNG, JPEG, GIF, BMP, TIFF и WebP на дисплей 128 x 128. Анимированные GIF сохраняют задержки кадров.",
    featureRgbTitle: "RGB и производительность",
    featureRgbText: "Настройка режима подсветки, яркости, скорости, направления, фиксированного цвета, response level и sleep timeout.",
    featureBatteryTitle: "Батарея и уведомления",
    featureBatteryText: "Чтение процента заряда через 2.4G приемник и локальное уведомление, когда заряд падает ниже 20%.",
    featureDiagnosticsTitle: "Диагностика HID",
    featureDiagnosticsText: "Панель endpoint-ов показывает transport, usage pages и размеры report-ов для быстрой проверки подключения и прав macOS.",
    workflowEyebrow: "Рабочий процесс",
    workflowTitle: "Два подключения - две зоны ответственности.",
    workflowText: "USB-C нужен для задач экрана и синхронизации часов. 2.4G приемник нужен для батареи, RGB, отклика, сна и Game Mode.",
    workflowItemClock: "Синхронизация часов клавиатуры с локальным временем macOS.",
    workflowItemReset: "Factory reset для display slots и конфигурационных блоков, которые использует приложение.",
    workflowItemLogin: "Launch at Login и выбор языка интерфейса.",
    workflowItemLocales: "Локализации: английский, русский, испанский, узбекский, казахский, португальский, упрощенный китайский.",
    detailsScreenshotAlt: "Диагностика HID endpoint-ов и настройки приложения",
    installEyebrow: "Установка",
    installTitle: "Скачайте DMG или соберите локально.",
    installReadyTitle: "Готовая сборка",
    installReadyText: "Откройте последнюю GitHub Release, скачайте DMG и перенесите приложение в Applications.",
    installReadyLink: "Открыть releases/latest",
    installBuildTitle: "Сборка из исходников",
    installBuildText: "Нужны macOS 14+, Apple Silicon Mac и Xcode Command Line Tools.",
    installPermissionsTitle: "Права macOS",
    installPermissionsText: "Если HID-команды не выполняются, выдайте приложению Input Monitoring и перезапустите его.",
    ctaEyebrow: "Открытый код",
    ctaTitle: "Нативный драйвер, который можно проверить и собрать самому.",
    sourceCode: "Исходный код",
    footerText: "macOS HID утилита для Epomaker x Aula F75 Max"
  },
  es: {
    metaDescription: "Aula F75 Max Driver es una utilidad nativa para macOS que configura el teclado Epomaker x Aula F75 Max, la pantalla, RGB, batería y modo 2.4G.",
    ogDescription: "Un controlador nativo y pulido para Aula F75 Max en macOS: pantalla, RGB, batería, Game Mode y diagnóstico HID.",
    navAria: "Navegación principal",
    navFeatures: "Funciones",
    navWorkflow: "Flujo",
    navInstall: "Instalar",
    languageLabel: "Idioma",
    heroEyebrow: "Utilidad nativa para macOS",
    heroTitle: "Controla Aula F75 Max sin controladores extra.",
    heroText: "Configura la pantalla del teclado, RGB, batería, nivel de respuesta y Game Mode desde una app enfocada para Macs con Apple Silicon.",
    downloadDmg: "Descargar DMG",
    howToInstall: "Cómo instalar",
    heroFactsAria: "Datos clave",
    mainScreenshotAlt: "Ventana principal de Aula F75 Max Driver",
    batteryLabel: "Batería",
    introDisplay: "Sube imágenes y GIF a la pantalla del teclado con modos fit, fill y stretch.",
    introWireless: "Controla batería, RGB, respuesta, suspensión y Game Mode mediante el receptor.",
    introHid: "Comunicación directa mediante las APIs HID de macOS, sin extensiones de kernel ni libusb.",
    featuresEyebrow: "Qué incluye",
    featuresTitle: "Herramientas creadas específicamente para el F75 Max.",
    featuresText: "La app separa las operaciones por cable de los ajustes 2.4G, para que quede claro qué conexión necesita cada tarea.",
    featureDisplayTitle: "Pantalla del teclado",
    featureDisplayText: "Sube archivos PNG, JPEG, GIF, BMP, TIFF y WebP a la pantalla de 128 x 128. Los GIF animados conservan sus retrasos de fotograma.",
    featureRgbTitle: "RGB y rendimiento",
    featureRgbText: "Configura modo de iluminación, brillo, velocidad, dirección, color fijo, nivel de respuesta y tiempo de suspensión.",
    featureBatteryTitle: "Batería y avisos",
    featureBatteryText: "Lee el porcentaje de batería mediante el receptor 2.4G y recibe una notificación local cuando baje del 20%.",
    featureDiagnosticsTitle: "Diagnóstico HID",
    featureDiagnosticsText: "El panel de endpoints muestra transporte, usage pages y tamaños de report para revisar rápido la conexión y permisos de macOS.",
    workflowEyebrow: "Flujo de trabajo",
    workflowTitle: "Dos conexiones, dos responsabilidades.",
    workflowText: "USB-C se usa para tareas de pantalla y sincronización del reloj. El receptor 2.4G se usa para batería, RGB, respuesta, suspensión y Game Mode.",
    workflowItemClock: "Sincroniza el reloj del teclado con la hora local de macOS.",
    workflowItemReset: "Restablecimiento de fábrica para slots de pantalla y bloques de configuración usados por esta app.",
    workflowItemLogin: "Launch at Login y selección del idioma de la interfaz.",
    workflowItemLocales: "Localizaciones: inglés, ruso, español, uzbeko, kazajo, portugués, chino simplificado.",
    detailsScreenshotAlt: "Diagnóstico de endpoints HID y ajustes de la app",
    installEyebrow: "Instalación",
    installTitle: "Descarga el DMG o compila localmente.",
    installReadyTitle: "Compilación lista",
    installReadyText: "Abre la última GitHub Release, descarga el DMG y mueve la app a Applications.",
    installReadyLink: "Abrir releases/latest",
    installBuildTitle: "Compilar desde código fuente",
    installBuildText: "Requiere macOS 14+, un Mac con Apple Silicon y Xcode Command Line Tools.",
    installPermissionsTitle: "Permisos de macOS",
    installPermissionsText: "Si los comandos HID no se ejecutan, concede permiso de Input Monitoring a la app y reiníciala.",
    ctaEyebrow: "Código abierto",
    ctaTitle: "Un controlador nativo que puedes inspeccionar y compilar tú mismo.",
    sourceCode: "Código fuente",
    footerText: "Utilidad HID para macOS compatible con Epomaker x Aula F75 Max"
  },
  uz: {
    metaDescription: "Aula F75 Max Driver - Epomaker x Aula F75 Max klaviaturasi, displey, RGB, batareya va 2.4G rejimini sozlash uchun native macOS utilitasi.",
    ogDescription: "Aula F75 Max uchun chiroyli native macOS drayveri: displeyga yuklash, RGB, batareya, Game Mode va HID diagnostikasi.",
    navAria: "Asosiy navigatsiya",
    navFeatures: "Imkoniyatlar",
    navWorkflow: "Jarayon",
    navInstall: "O'rnatish",
    languageLabel: "Til",
    heroEyebrow: "Native macOS utilitasi",
    heroTitle: "Aula F75 Max boshqaruvi ortiqcha drayverlarsiz.",
    heroText: "Klaviatura displeyi, RGB yoritish, batareya holati, javob darajasi va Game Mode sozlamalarini Apple Silicon Mac uchun bitta qulay ilovadan boshqaring.",
    downloadDmg: "DMG yuklab olish",
    howToInstall: "Qanday o'rnatiladi",
    heroFactsAria: "Asosiy ma'lumotlar",
    mainScreenshotAlt: "Aula F75 Max Driver asosiy oynasi",
    batteryLabel: "Batareya",
    introDisplay: "Rasm va GIF fayllarni klaviatura displeyiga fit, fill va stretch rejimlarida yuklang.",
    introWireless: "Qabul qilgich orqali batareya, RGB, javob, uyqu va Game Mode boshqaruvi.",
    introHid: "macOS HID API orqali kernel extensions va libusb ishlatmasdan bevosita aloqa.",
    featuresEyebrow: "Ichida nima bor",
    featuresTitle: "Aynan F75 Max uchun yaratilgan vositalar.",
    featuresText: "Ilova simli operatsiyalarni 2.4G sozlamalaridan ajratadi, shuning uchun har bir vazifa qaysi ulanishni talab qilishi aniq.",
    featureDisplayTitle: "Klaviatura displeyi",
    featureDisplayText: "PNG, JPEG, GIF, BMP, TIFF va WebP fayllarni 128 x 128 displeyga yuklang. Animatsiyali GIF kadr kechikishlarini saqlaydi.",
    featureRgbTitle: "RGB va unumdorlik",
    featureRgbText: "Yoritish rejimi, yorqinlik, tezlik, yo'nalish, doimiy rang, response level va sleep timeout sozlamalari.",
    featureBatteryTitle: "Batareya va ogohlantirishlar",
    featureBatteryText: "2.4G qabul qilgich orqali batareya foizini o'qing va 20% dan pastga tushganda lokal bildirishnoma oling.",
    featureDiagnosticsTitle: "HID diagnostikasi",
    featureDiagnosticsText: "Endpoint paneli ulanish va macOS ruxsatlarini tez tekshirish uchun transport, usage pages va report o'lchamlarini ko'rsatadi.",
    workflowEyebrow: "Ish jarayoni",
    workflowTitle: "Ikki ulanish - ikki mas'uliyat sohasi.",
    workflowText: "USB-C displey vazifalari va soat sinxronlash uchun ishlatiladi. 2.4G qabul qilgich batareya, RGB, javob, uyqu va Game Mode uchun ishlatiladi.",
    workflowItemClock: "Klaviatura soatini macOS lokal vaqti bilan sinxronlash.",
    workflowItemReset: "Ushbu ilova ishlatadigan display slots va konfiguratsiya bloklari uchun factory reset.",
    workflowItemLogin: "Launch at Login va interfeys tilini tanlash.",
    workflowItemLocales: "Lokalizatsiyalar: ingliz, rus, ispan, o'zbek, qozoq, portugal, soddalashtirilgan xitoy.",
    detailsScreenshotAlt: "HID endpoint diagnostikasi va ilova sozlamalari",
    installEyebrow: "O'rnatish",
    installTitle: "DMG yuklab oling yoki lokal yig'ing.",
    installReadyTitle: "Tayyor build",
    installReadyText: "Oxirgi GitHub Release sahifasini oching, DMG yuklab oling va ilovani Applications papkasiga ko'chiring.",
    installReadyLink: "releases/latest ochish",
    installBuildTitle: "Manbadan yig'ish",
    installBuildText: "macOS 14+, Apple Silicon Mac va Xcode Command Line Tools talab qilinadi.",
    installPermissionsTitle: "macOS ruxsatlari",
    installPermissionsText: "Agar HID buyruqlari ishlamasa, ilovaga Input Monitoring ruxsatini bering va uni qayta ishga tushiring.",
    ctaEyebrow: "Ochiq kod",
    ctaTitle: "Tekshirishingiz va o'zingiz yig'ishingiz mumkin bo'lgan native drayver.",
    sourceCode: "Manba kodi",
    footerText: "Epomaker x Aula F75 Max uchun macOS HID utilitasi"
  },
  kk: {
    metaDescription: "Aula F75 Max Driver - Epomaker x Aula F75 Max пернетақтасын, дисплейін, RGB жарығын, батареясын және 2.4G режимін баптауға арналған native macOS утилитасы.",
    ogDescription: "Aula F75 Max үшін жинақы native macOS драйвері: дисплейге жүктеу, RGB, батарея, Game Mode және HID диагностикасы.",
    navAria: "Негізгі навигация",
    navFeatures: "Мүмкіндіктер",
    navWorkflow: "Жұмыс барысы",
    navInstall: "Орнату",
    languageLabel: "Тіл",
    heroEyebrow: "Native macOS утилитасы",
    heroTitle: "Aula F75 Max басқаруы артық драйверлерсіз.",
    heroText: "Пернетақта дисплейін, RGB жарығын, батарея күйін, жауап деңгейін және Game Mode режимін Apple Silicon Mac үшін бір ықшам қолданбадан баптаңыз.",
    downloadDmg: "DMG жүктеу",
    howToInstall: "Қалай орнату",
    heroFactsAria: "Негізгі деректер",
    mainScreenshotAlt: "Aula F75 Max Driver негізгі терезесі",
    batteryLabel: "Батарея",
    introDisplay: "Суреттер мен GIF файлдарын пернетақта дисплейіне fit, fill және stretch режимдерімен жүктеңіз.",
    introWireless: "Қабылдағыш арқылы батареяны, RGB жарығын, жауапты, ұйқыны және Game Mode режимін басқарыңыз.",
    introHid: "macOS HID API арқылы kernel extensions және libusb қолданбай тікелей байланыс.",
    featuresEyebrow: "Ішінде не бар",
    featuresTitle: "F75 Max үшін арнайы жасалған құралдар.",
    featuresText: "Қолданба сымды операцияларды 2.4G баптауларынан бөледі, сондықтан әр тапсырмаға қай қосылу керек екені анық.",
    featureDisplayTitle: "Пернетақта дисплейі",
    featureDisplayText: "PNG, JPEG, GIF, BMP, TIFF және WebP файлдарын 128 x 128 дисплейге жүктеңіз. Анимациялы GIF кадр кідірістерін сақтайды.",
    featureRgbTitle: "RGB және өнімділік",
    featureRgbText: "Жарық режимін, жарықтықты, жылдамдықты, бағытты, тұрақты түсті, response level және sleep timeout мәндерін баптаңыз.",
    featureBatteryTitle: "Батарея және ескертулер",
    featureBatteryText: "2.4G қабылдағыш арқылы батарея пайызын оқып, заряд 20%-дан төмен түскенде жергілікті хабарлама алыңыз.",
    featureDiagnosticsTitle: "HID диагностикасы",
    featureDiagnosticsText: "Endpoint панелі қосылуды және macOS рұқсаттарын жылдам тексеру үшін transport, usage pages және report өлшемдерін көрсетеді.",
    workflowEyebrow: "Жұмыс процесі",
    workflowTitle: "Екі қосылу - екі жауапкершілік аймағы.",
    workflowText: "USB-C дисплей тапсырмалары мен сағатты синхрондау үшін қолданылады. 2.4G қабылдағыш батарея, RGB, жауап, ұйқы және Game Mode үшін қолданылады.",
    workflowItemClock: "Пернетақта сағатын macOS жергілікті уақытымен синхрондау.",
    workflowItemReset: "Осы қолданба пайдаланатын display slots және конфигурация блоктары үшін factory reset.",
    workflowItemLogin: "Launch at Login және интерфейс тілін таңдау.",
    workflowItemLocales: "Локализациялар: ағылшын, орыс, испан, өзбек, қазақ, португал, жеңілдетілген қытай.",
    detailsScreenshotAlt: "HID endpoint диагностикасы және қолданба баптаулары",
    installEyebrow: "Орнату",
    installTitle: "DMG жүктеңіз немесе жергілікті жинаңыз.",
    installReadyTitle: "Дайын build",
    installReadyText: "Соңғы GitHub Release бетін ашып, DMG жүктеңіз және қолданбаны Applications ішіне көшіріңіз.",
    installReadyLink: "releases/latest ашу",
    installBuildTitle: "Бастапқы кодтан жинау",
    installBuildText: "macOS 14+, Apple Silicon Mac және Xcode Command Line Tools қажет.",
    installPermissionsTitle: "macOS рұқсаттары",
    installPermissionsText: "Егер HID командалары орындалмаса, қолданбаға Input Monitoring рұқсатын беріп, оны қайта іске қосыңыз.",
    ctaEyebrow: "Ашық код",
    ctaTitle: "Тексеріп, өзіңіз жинай алатын native драйвер.",
    sourceCode: "Бастапқы код",
    footerText: "Epomaker x Aula F75 Max үшін macOS HID утилитасы"
  },
  pt: {
    metaDescription: "Aula F75 Max Driver é um utilitário nativo para macOS que configura o teclado Epomaker x Aula F75 Max, tela, RGB, bateria e modo 2.4G.",
    ogDescription: "Um driver nativo e bem acabado para Aula F75 Max no macOS: envio para tela, RGB, bateria, Game Mode e diagnóstico HID.",
    navAria: "Navegação principal",
    navFeatures: "Recursos",
    navWorkflow: "Fluxo",
    navInstall: "Instalar",
    languageLabel: "Idioma",
    heroEyebrow: "Utilitário nativo para macOS",
    heroTitle: "Controle o Aula F75 Max sem drivers extras.",
    heroText: "Configure a tela do teclado, RGB, bateria, nível de resposta e Game Mode em um app focado para Macs com Apple Silicon.",
    downloadDmg: "Baixar DMG",
    howToInstall: "Como instalar",
    heroFactsAria: "Fatos principais",
    mainScreenshotAlt: "Janela principal do Aula F75 Max Driver",
    batteryLabel: "Bateria",
    introDisplay: "Envie imagens e GIFs para a tela do teclado com os modos fit, fill e stretch.",
    introWireless: "Controle bateria, RGB, resposta, suspensão e Game Mode pelo receptor.",
    introHid: "Comunicação direta pelas APIs HID do macOS, sem extensões de kernel ou libusb.",
    featuresEyebrow: "O que inclui",
    featuresTitle: "Ferramentas criadas especificamente para o F75 Max.",
    featuresText: "O app separa operações com cabo das configurações 2.4G, deixando claro qual conexão cada tarefa exige.",
    featureDisplayTitle: "Tela do teclado",
    featureDisplayText: "Envie PNG, JPEG, GIF, BMP, TIFF e WebP para a tela 128 x 128. GIFs animados mantêm os atrasos de quadro.",
    featureRgbTitle: "RGB e desempenho",
    featureRgbText: "Configure modo de iluminação, brilho, velocidade, direção, cor fixa, response level e sleep timeout.",
    featureBatteryTitle: "Bateria e alertas",
    featureBatteryText: "Leia a porcentagem da bateria pelo receptor 2.4G e receba uma notificação local quando ela cair abaixo de 20%.",
    featureDiagnosticsTitle: "Diagnóstico HID",
    featureDiagnosticsText: "O painel de endpoints mostra transporte, usage pages e tamanhos de report para verificar conexão e permissões do macOS rapidamente.",
    workflowEyebrow: "Fluxo de trabalho",
    workflowTitle: "Duas conexões, duas áreas de responsabilidade.",
    workflowText: "USB-C é usado para tarefas da tela e sincronização do relógio. O receptor 2.4G é usado para bateria, RGB, resposta, suspensão e Game Mode.",
    workflowItemClock: "Sincronize o relógio do teclado com o horário local do macOS.",
    workflowItemReset: "Factory reset para display slots e blocos de configuração usados por este app.",
    workflowItemLogin: "Launch at Login e seleção do idioma da interface.",
    workflowItemLocales: "Localizações: inglês, russo, espanhol, uzbeque, cazaque, português, chinês simplificado.",
    detailsScreenshotAlt: "Diagnóstico de endpoints HID e configurações do app",
    installEyebrow: "Instalação",
    installTitle: "Baixe o DMG ou compile localmente.",
    installReadyTitle: "Build pronto",
    installReadyText: "Abra a GitHub Release mais recente, baixe o DMG e mova o app para Applications.",
    installReadyLink: "Abrir releases/latest",
    installBuildTitle: "Compilar do código-fonte",
    installBuildText: "Requer macOS 14+, um Mac com Apple Silicon e Xcode Command Line Tools.",
    installPermissionsTitle: "Permissões do macOS",
    installPermissionsText: "Se os comandos HID não executarem, conceda permissão de Input Monitoring ao app e reinicie-o.",
    ctaEyebrow: "Código aberto",
    ctaTitle: "Um driver nativo que você pode inspecionar e compilar por conta própria.",
    sourceCode: "Código-fonte",
    footerText: "Utilitário HID para macOS compatível com Epomaker x Aula F75 Max"
  },
  "zh-Hans": {
    metaDescription: "Aula F75 Max Driver 是一款原生 macOS 工具，用于配置 Epomaker x Aula F75 Max 键盘、屏幕、RGB 灯效、电池和 2.4G 模式。",
    ogDescription: "面向 Aula F75 Max 的精致原生 macOS 驱动：屏幕上传、RGB、电池、Game Mode 和 HID 诊断。",
    navAria: "主导航",
    navFeatures: "功能",
    navWorkflow: "流程",
    navInstall: "安装",
    languageLabel: "语言",
    heroEyebrow: "原生 macOS 工具",
    heroTitle: "无需额外驱动即可控制 Aula F75 Max。",
    heroText: "在一个专注的 Apple Silicon Mac 应用中配置键盘屏幕、RGB 灯效、电池状态、响应等级和 Game Mode。",
    downloadDmg: "下载 DMG",
    howToInstall: "安装方法",
    heroFactsAria: "关键信息",
    mainScreenshotAlt: "Aula F75 Max Driver 主窗口",
    batteryLabel: "电池",
    introDisplay: "以 fit、fill 和 stretch 模式将图片和 GIF 上传到键盘屏幕。",
    introWireless: "通过接收器控制电池、RGB、响应、睡眠和 Game Mode。",
    introHid: "通过 macOS HID API 直接通信，无需 kernel extensions 或 libusb。",
    featuresEyebrow: "包含内容",
    featuresTitle: "专为 F75 Max 构建的工具。",
    featuresText: "应用将有线操作与 2.4G 设置分开，让每个任务需要哪种连接一目了然。",
    featureDisplayTitle: "键盘屏幕",
    featureDisplayText: "将 PNG、JPEG、GIF、BMP、TIFF 和 WebP 上传到 128 x 128 屏幕。动态 GIF 会保留帧延迟。",
    featureRgbTitle: "RGB 与性能",
    featureRgbText: "配置灯效模式、亮度、速度、方向、固定颜色、response level 和 sleep timeout。",
    featureBatteryTitle: "电池与提醒",
    featureBatteryText: "通过 2.4G 接收器读取电量百分比，并在低于 20% 时收到本地通知。",
    featureDiagnosticsTitle: "HID 诊断",
    featureDiagnosticsText: "Endpoint 面板显示 transport、usage pages 和 report 大小，便于快速检查连接和 macOS 权限。",
    workflowEyebrow: "工作流程",
    workflowTitle: "两种连接，两类职责。",
    workflowText: "USB-C 用于屏幕任务和时钟同步。2.4G 接收器用于电池、RGB、响应、睡眠和 Game Mode。",
    workflowItemClock: "将键盘时钟同步到 macOS 本地时间。",
    workflowItemReset: "对本应用使用的 display slots 和配置块执行 factory reset。",
    workflowItemLogin: "Launch at Login 和界面语言选择。",
    workflowItemLocales: "本地化：英语、俄语、西班牙语、乌兹别克语、哈萨克语、葡萄牙语、简体中文。",
    detailsScreenshotAlt: "HID endpoint 诊断和应用设置",
    installEyebrow: "安装",
    installTitle: "下载 DMG 或在本地构建。",
    installReadyTitle: "现成构建",
    installReadyText: "打开最新 GitHub Release，下载 DMG，并将应用移到 Applications。",
    installReadyLink: "打开 releases/latest",
    installBuildTitle: "从源码构建",
    installBuildText: "需要 macOS 14+、Apple Silicon Mac 和 Xcode Command Line Tools。",
    installPermissionsTitle: "macOS 权限",
    installPermissionsText: "如果 HID 命令无法执行，请授予应用 Input Monitoring 权限并重启应用。",
    ctaEyebrow: "开源",
    ctaTitle: "一个可以自行检查和构建的原生驱动。",
    sourceCode: "源代码",
    footerText: "面向 Epomaker x Aula F75 Max 的 macOS HID 工具"
  }
};

const fallbackLanguage = "en";
const languageStorageKey = "aula-docs-language";
const languageSelect = document.querySelector("#language-select");
const revealItems = document.querySelectorAll("[data-reveal]");

function resolveLanguage(language) {
  return Object.prototype.hasOwnProperty.call(translations, language) ? language : fallbackLanguage;
}

function readStoredLanguage() {
  try {
    return localStorage.getItem(languageStorageKey);
  } catch {
    return null;
  }
}

function storeLanguage(language) {
  try {
    localStorage.setItem(languageStorageKey, language);
  } catch {
    // The selector still works for the current page view when storage is blocked.
  }
}

function applyTranslations(language) {
  const resolvedLanguage = resolveLanguage(language);
  const dictionary = translations[resolvedLanguage];

  document.documentElement.lang = resolvedLanguage;
  document
    .querySelector('meta[name="description"]')
    ?.setAttribute("content", dictionary.metaDescription);
  document
    .querySelector('meta[property="og:description"]')
    ?.setAttribute("content", dictionary.ogDescription);

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.dataset.i18n;
    if (dictionary[key]) {
      element.textContent = dictionary[key];
    }
  });

  document.querySelectorAll("[data-i18n-aria-label]").forEach((element) => {
    const key = element.dataset.i18nAriaLabel;
    if (dictionary[key]) {
      element.setAttribute("aria-label", dictionary[key]);
    }
  });

  document.querySelectorAll("[data-i18n-alt]").forEach((element) => {
    const key = element.dataset.i18nAlt;
    if (dictionary[key]) {
      element.setAttribute("alt", dictionary[key]);
    }
  });

  if (languageSelect) {
    languageSelect.value = resolvedLanguage;
  }
}

function initialLanguage() {
  return resolveLanguage(readStoredLanguage() || fallbackLanguage);
}

languageSelect?.addEventListener("change", (event) => {
  const language = resolveLanguage(event.target.value);
  storeLanguage(language);
  applyTranslations(language);
});

applyTranslations(initialLanguage());

if ("IntersectionObserver" in window) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { rootMargin: "0px 0px -10% 0px", threshold: 0.12 }
  );

  revealItems.forEach((item, index) => {
    item.style.transitionDelay = `${Math.min(index * 45, 260)}ms`;
    observer.observe(item);
  });
} else {
  revealItems.forEach((item) => item.classList.add("is-visible"));
}
