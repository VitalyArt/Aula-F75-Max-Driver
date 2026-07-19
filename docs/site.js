const translations = {
  en: {
    metaDescription: "Aula F75 Max Driver is a native macOS, Linux, and Android utility for configuring the Epomaker x Aula F75 Max keyboard, display, RGB lighting, battery, and 2.4G mode.",
    ogDescription: "A polished native macOS, Linux, and Android driver for Aula F75 Max: display uploads, RGB, battery, Game Mode, and HID diagnostics.",
    navAria: "Primary navigation",
    navFeatures: "Features",
    navWorkflow: "Workflow",
    navInstall: "Install",
    languageLabel: "Language",
    heroEyebrow: "Native macOS, Linux, and Android utility",
    heroTitle: "Control Aula F75 Max on desktop or Android.",
    heroText: "Configure the keyboard display, RGB lighting, battery status, response level, and Game Mode from one focused app across all three platforms.",
    downloadDmg: "Download release",
    howToInstall: "How to install",
    heroFactsAria: "Key facts",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "Android 9+ with USB OTG",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Aula F75 Max Driver main window",
    batteryLabel: "Battery",
    introDisplay: "Upload images and GIFs to the keyboard display with fit, fill, and stretch modes.",
    introWireless: "Control battery, RGB lighting, response, sleep, and Game Mode through the receiver.",
    introHid: "Direct communication through macOS HID APIs, Linux hidraw/hidapi, and Android USB Host.",
    featuresEyebrow: "What's inside",
    featuresTitle: "Tools built specifically for the F75 Max.",
    featuresText: "The app separates wired operations from 2.4G settings, so it is clear which connection mode each task needs on every platform.",
    featureDisplayTitle: "Keyboard display",
    featureDisplayText: "Upload PNG, JPEG, GIF, BMP, TIFF, and WebP files to the 128 x 128 display. Animated GIFs keep their frame delays.",
    featureRgbTitle: "RGB and performance",
    featureRgbText: "Configure lighting mode, brightness, speed, direction, fixed color, response level, and sleep timeout.",
    featureBatteryTitle: "Battery and alerts",
    featureBatteryText: "Read battery percentage through the 2.4G receiver. Desktop apps can also notify you when it drops below 20%.",
    featureDiagnosticsTitle: "HID diagnostics",
    featureDiagnosticsText: "The endpoints panel shows transport, usage pages, and report sizes for quick connection and permission checks.",
    workflowEyebrow: "Workflow",
    workflowTitle: "Two connections, two areas of responsibility.",
    workflowText: "USB-C is used for display tasks and clock sync. The 2.4G receiver is used for battery, RGB, response, sleep, and Game Mode.",
    workflowItemClock: "Sync the keyboard clock to the local device time.",
    workflowItemReset: "Factory reset for display slots and configuration blocks used by this app.",
    workflowItemLogin: "Launch at Login on macOS and interface language selection on every platform.",
    workflowItemLocales: "Android includes English and Russian; desktop apps include seven localizations.",
    detailsScreenshotAlt: "HID endpoint diagnostics and app settings",
    installEyebrow: "Install",
    installTitle: "Download a DMG, DEB, or Android APK.",
    installReadyTitle: "Ready-made build",
    installReadyText: "Open GitHub Releases for the macOS DMG, Debian/Ubuntu DEB, and APK in future Android releases.",
    installReadyLink: "Open releases/latest",
    installBuildTitle: "Build from source",
    installBuildText: "Desktop builds use Xcode tools or Swift 6 with GTK4 and hidapi. Android builds require JDK 17 and the Android SDK.",
    installPermissionsTitle: "Platform permissions",
    installPermissionsText: "On Android 9+, connect through USB OTG, tap Grant USB access, and approve the system prompt. macOS uses Input Monitoring; Linux uses a udev rule.",
    ctaEyebrow: "Open source",
    ctaTitle: "A native driver you can inspect and build yourself.",
    sourceCode: "Source code",
    footerText: "macOS, Linux, and Android utility for Epomaker x Aula F75 Max"
  },
  ru: {
    metaDescription: "Aula F75 Max Driver - нативная утилита для macOS, Linux и Android для настройки клавиатуры Epomaker x Aula F75 Max, дисплея, RGB, батареи и режима 2.4G.",
    ogDescription: "Аккуратный нативный драйвер для Aula F75 Max на macOS, Linux и Android: загрузка на экран, RGB, батарея, Game Mode и диагностика HID.",
    navAria: "Основная навигация",
    navFeatures: "Возможности",
    navWorkflow: "Сценарии",
    navInstall: "Установка",
    languageLabel: "Язык",
    heroEyebrow: "Нативная утилита для macOS, Linux и Android",
    heroTitle: "Управляйте Aula F75 Max на компьютере или Android.",
    heroText: "Настраивайте экран клавиатуры, RGB, батарею, отклик и Game Mode из одного приложения на всех трёх платформах.",
    downloadDmg: "Скачать релиз",
    howToInstall: "Как установить",
    heroFactsAria: "Ключевые факты",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "Android 9+ с USB OTG",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Главное окно Aula F75 Max Driver",
    batteryLabel: "Батарея",
    introDisplay: "Загрузка изображений и GIF на экран клавиатуры с режимами fit, fill и stretch.",
    introWireless: "Управление батареей, RGB, откликом, сном и игровым режимом через приемник.",
    introHid: "Прямая работа через macOS HID APIs, Linux hidraw/hidapi и Android USB Host.",
    featuresEyebrow: "Что внутри",
    featuresTitle: "Инструменты, которые нужны именно для F75 Max.",
    featuresText: "Приложение разделяет проводные операции и 2.4G-настройки, чтобы на каждой платформе было понятно, какое подключение нужно для задачи.",
    featureDisplayTitle: "Экран клавиатуры",
    featureDisplayText: "Загружайте PNG, JPEG, GIF, BMP, TIFF и WebP на дисплей 128 x 128. Анимированные GIF сохраняют задержки кадров.",
    featureRgbTitle: "RGB и производительность",
    featureRgbText: "Настройка режима подсветки, яркости, скорости, направления, фиксированного цвета, response level и sleep timeout.",
    featureBatteryTitle: "Батарея и уведомления",
    featureBatteryText: "Чтение процента заряда через 2.4G-приёмник. На компьютере приложение также уведомляет, когда заряд падает ниже 20%.",
    featureDiagnosticsTitle: "Диагностика HID",
    featureDiagnosticsText: "Панель endpoint-ов показывает transport, usage pages и размеры report-ов для быстрой проверки подключения и разрешений.",
    workflowEyebrow: "Рабочий процесс",
    workflowTitle: "Два подключения - две зоны ответственности.",
    workflowText: "USB-C нужен для задач экрана и синхронизации часов. 2.4G приемник нужен для батареи, RGB, отклика, сна и Game Mode.",
    workflowItemClock: "Синхронизация часов клавиатуры с локальным временем устройства.",
    workflowItemReset: "Factory reset для display slots и конфигурационных блоков, которые использует приложение.",
    workflowItemLogin: "Launch at Login на macOS и выбор языка интерфейса на каждой платформе.",
    workflowItemLocales: "Android включает английский и русский; приложения для компьютера включают семь локализаций.",
    detailsScreenshotAlt: "Диагностика HID endpoint-ов и настройки приложения",
    installEyebrow: "Установка",
    installTitle: "Скачайте DMG, DEB или Android APK.",
    installReadyTitle: "Готовая сборка",
    installReadyText: "В GitHub Releases доступны macOS DMG, Debian/Ubuntu DEB и APK в будущих Android-релизах.",
    installReadyLink: "Открыть releases/latest",
    installBuildTitle: "Сборка из исходников",
    installBuildText: "Для компьютера нужны инструменты Xcode или Swift 6 с GTK4 и hidapi. Для Android нужны JDK 17 и Android SDK.",
    installPermissionsTitle: "Права платформы",
    installPermissionsText: "На Android 9+ подключите устройство через USB OTG, нажмите «Разрешить доступ по USB» и подтвердите системный запрос. macOS использует Input Monitoring, Linux - правило udev.",
    ctaEyebrow: "Открытый код",
    ctaTitle: "Нативный драйвер, который можно проверить и собрать самому.",
    sourceCode: "Исходный код",
    footerText: "Утилита для macOS, Linux и Android для Epomaker x Aula F75 Max"
  },
  es: {
    metaDescription: "Aula F75 Max Driver es una utilidad nativa para macOS, Linux y Android que configura el teclado Epomaker x Aula F75 Max, la pantalla, RGB, batería y modo 2.4G.",
    ogDescription: "Un controlador nativo para Aula F75 Max en macOS, Linux y Android: pantalla, RGB, batería, Game Mode y diagnóstico HID.",
    navAria: "Navegación principal",
    navFeatures: "Funciones",
    navWorkflow: "Flujo",
    navInstall: "Instalar",
    languageLabel: "Idioma",
    heroEyebrow: "Utilidad nativa para macOS, Linux y Android",
    heroTitle: "Controla Aula F75 Max en el escritorio o Android.",
    heroText: "Configura la pantalla del teclado, RGB, batería, nivel de respuesta y Game Mode desde una app en las tres plataformas.",
    downloadDmg: "Descargar release",
    howToInstall: "Cómo instalar",
    heroFactsAria: "Datos clave",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "Android 9+ con USB OTG",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Ventana principal de Aula F75 Max Driver",
    batteryLabel: "Batería",
    introDisplay: "Sube imágenes y GIF a la pantalla del teclado con modos fit, fill y stretch.",
    introWireless: "Controla batería, RGB, respuesta, suspensión y Game Mode mediante el receptor.",
    introHid: "Comunicación directa mediante las APIs HID de macOS, Linux hidraw/hidapi y Android USB Host.",
    featuresEyebrow: "Qué incluye",
    featuresTitle: "Herramientas creadas específicamente para el F75 Max.",
    featuresText: "La app separa las operaciones por cable de los ajustes 2.4G, para que quede claro qué conexión necesita cada tarea en cada plataforma.",
    featureDisplayTitle: "Pantalla del teclado",
    featureDisplayText: "Sube archivos PNG, JPEG, GIF, BMP, TIFF y WebP a la pantalla de 128 x 128. Los GIF animados conservan sus retrasos de fotograma.",
    featureRgbTitle: "RGB y rendimiento",
    featureRgbText: "Configura modo de iluminación, brillo, velocidad, dirección, color fijo, nivel de respuesta y tiempo de suspensión.",
    featureBatteryTitle: "Batería y avisos",
    featureBatteryText: "Lee el porcentaje de batería mediante el receptor 2.4G. Las apps de escritorio también avisan cuando baja del 20%.",
    featureDiagnosticsTitle: "Diagnóstico HID",
    featureDiagnosticsText: "El panel de endpoints muestra transporte, usage pages y tamaños de report para revisar la conexión y los permisos.",
    workflowEyebrow: "Flujo de trabajo",
    workflowTitle: "Dos conexiones, dos responsabilidades.",
    workflowText: "USB-C se usa para tareas de pantalla y sincronización del reloj. El receptor 2.4G se usa para batería, RGB, respuesta, suspensión y Game Mode.",
    workflowItemClock: "Sincroniza el reloj del teclado con la hora local del dispositivo.",
    workflowItemReset: "Restablecimiento de fábrica para slots de pantalla y bloques de configuración usados por esta app.",
    workflowItemLogin: "Launch at Login en macOS y selección del idioma en cada plataforma.",
    workflowItemLocales: "Android incluye inglés y ruso; las apps de escritorio incluyen siete localizaciones.",
    detailsScreenshotAlt: "Diagnóstico de endpoints HID y ajustes de la app",
    installEyebrow: "Instalación",
    installTitle: "Descarga un DMG, DEB o APK de Android.",
    installReadyTitle: "Compilación lista",
    installReadyText: "Abre GitHub Releases para obtener el DMG de macOS, el DEB para Debian/Ubuntu y el APK en futuras versiones de Android.",
    installReadyLink: "Abrir releases/latest",
    installBuildTitle: "Compilar desde código fuente",
    installBuildText: "El escritorio usa Xcode o Swift 6 con GTK4 e hidapi. Android requiere JDK 17 y Android SDK.",
    installPermissionsTitle: "Permisos de la plataforma",
    installPermissionsText: "En Android 9+, conecta mediante USB OTG, pulsa Grant USB access y acepta el permiso. macOS usa Input Monitoring y Linux una regla udev.",
    ctaEyebrow: "Código abierto",
    ctaTitle: "Un controlador nativo que puedes inspeccionar y compilar tú mismo.",
    sourceCode: "Código fuente",
    footerText: "Utilidad para macOS, Linux y Android compatible con Epomaker x Aula F75 Max"
  },
  uz: {
    metaDescription: "Aula F75 Max Driver - Epomaker x Aula F75 Max klaviaturasi, displey, RGB, batareya va 2.4G rejimini sozlash uchun macOS, Linux va Android utilitasi.",
    ogDescription: "Aula F75 Max uchun macOS, Linux va Android drayveri: displeyga yuklash, RGB, batareya, Game Mode va HID diagnostikasi.",
    navAria: "Asosiy navigatsiya",
    navFeatures: "Imkoniyatlar",
    navWorkflow: "Jarayon",
    navInstall: "O'rnatish",
    languageLabel: "Til",
    heroEyebrow: "macOS, Linux va Android utilitasi",
    heroTitle: "Aula F75 Max ni kompyuter yoki Androidda boshqaring.",
    heroText: "Klaviatura displeyi, RGB, batareya, javob darajasi va Game Mode sozlamalarini uchala platformada bitta ilovadan boshqaring.",
    downloadDmg: "Release yuklab olish",
    howToInstall: "Qanday o'rnatiladi",
    heroFactsAria: "Asosiy ma'lumotlar",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "USB OTG bilan Android 9+",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Aula F75 Max Driver asosiy oynasi",
    batteryLabel: "Batareya",
    introDisplay: "Rasm va GIF fayllarni klaviatura displeyiga fit, fill va stretch rejimlarida yuklang.",
    introWireless: "Qabul qilgich orqali batareya, RGB, javob, uyqu va Game Mode boshqaruvi.",
    introHid: "macOS HID API, Linux hidraw/hidapi va Android USB Host orqali bevosita aloqa.",
    featuresEyebrow: "Ichida nima bor",
    featuresTitle: "Aynan F75 Max uchun yaratilgan vositalar.",
    featuresText: "Ilova simli operatsiyalarni 2.4G sozlamalaridan ajratadi, shuning uchun har bir platformada vazifa uchun kerakli ulanish aniq.",
    featureDisplayTitle: "Klaviatura displeyi",
    featureDisplayText: "PNG, JPEG, GIF, BMP, TIFF va WebP fayllarni 128 x 128 displeyga yuklang. Animatsiyali GIF kadr kechikishlarini saqlaydi.",
    featureRgbTitle: "RGB va unumdorlik",
    featureRgbText: "Yoritish rejimi, yorqinlik, tezlik, yo'nalish, doimiy rang, response level va sleep timeout sozlamalari.",
    featureBatteryTitle: "Batareya va ogohlantirishlar",
    featureBatteryText: "2.4G qabul qilgich orqali batareya foizini o'qing. Kompyuter ilovalari 20% dan pastga tushganda ham ogohlantiradi.",
    featureDiagnosticsTitle: "HID diagnostikasi",
    featureDiagnosticsText: "Endpoint paneli ulanish va ruxsatlarni tekshirish uchun transport, usage pages va report o'lchamlarini ko'rsatadi.",
    workflowEyebrow: "Ish jarayoni",
    workflowTitle: "Ikki ulanish - ikki mas'uliyat sohasi.",
    workflowText: "USB-C displey vazifalari va soat sinxronlash uchun ishlatiladi. 2.4G qabul qilgich batareya, RGB, javob, uyqu va Game Mode uchun ishlatiladi.",
    workflowItemClock: "Klaviatura soatini qurilmaning lokal vaqti bilan sinxronlash.",
    workflowItemReset: "Ushbu ilova ishlatadigan display slots va konfiguratsiya bloklari uchun factory reset.",
    workflowItemLogin: "macOSda Launch at Login va har bir platformada interfeys tilini tanlash.",
    workflowItemLocales: "Android ingliz va rus tillarini, kompyuter ilovalari esa yetti lokalizatsiyani o'z ichiga oladi.",
    detailsScreenshotAlt: "HID endpoint diagnostikasi va ilova sozlamalari",
    installEyebrow: "O'rnatish",
    installTitle: "DMG, DEB yoki Android APK yuklab oling.",
    installReadyTitle: "Tayyor build",
    installReadyText: "GitHub Releases sahifasidan macOS DMG, Debian/Ubuntu DEB va kelajakdagi Android relizlarida APK faylini yuklab oling.",
    installReadyLink: "releases/latest ochish",
    installBuildTitle: "Manbadan yig'ish",
    installBuildText: "Kompyuter buildi Xcode yoki GTK4 va hidapi bilan Swift 6 ishlatadi. Android uchun JDK 17 va Android SDK kerak.",
    installPermissionsTitle: "Platforma ruxsatlari",
    installPermissionsText: "Android 9+ da USB OTG orqali ulang, Grant USB access tugmasini bosing va ruxsatni tasdiqlang. macOS Input Monitoring, Linux esa udev qoidasidan foydalanadi.",
    ctaEyebrow: "Ochiq kod",
    ctaTitle: "Tekshirishingiz va o'zingiz yig'ishingiz mumkin bo'lgan native drayver.",
    sourceCode: "Manba kodi",
    footerText: "Epomaker x Aula F75 Max uchun macOS, Linux va Android utilitasi"
  },
  kk: {
    metaDescription: "Aula F75 Max Driver - Epomaker x Aula F75 Max пернетақтасын, дисплейін, RGB жарығын, батареясын және 2.4G режимін баптауға арналған macOS, Linux және Android утилитасы.",
    ogDescription: "Aula F75 Max үшін macOS, Linux және Android драйвері: дисплейге жүктеу, RGB, батарея, Game Mode және HID диагностикасы.",
    navAria: "Негізгі навигация",
    navFeatures: "Мүмкіндіктер",
    navWorkflow: "Жұмыс барысы",
    navInstall: "Орнату",
    languageLabel: "Тіл",
    heroEyebrow: "macOS, Linux және Android утилитасы",
    heroTitle: "Aula F75 Max-ты компьютерде немесе Android-та басқарыңыз.",
    heroText: "Пернетақта дисплейін, RGB жарығын, батарея күйін, жауап деңгейін және Game Mode режимін үш платформада бір қолданбадан баптаңыз.",
    downloadDmg: "Release жүктеу",
    howToInstall: "Қалай орнату",
    heroFactsAria: "Негізгі деректер",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "USB OTG бар Android 9+",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Aula F75 Max Driver негізгі терезесі",
    batteryLabel: "Батарея",
    introDisplay: "Суреттер мен GIF файлдарын пернетақта дисплейіне fit, fill және stretch режимдерімен жүктеңіз.",
    introWireless: "Қабылдағыш арқылы батареяны, RGB жарығын, жауапты, ұйқыны және Game Mode режимін басқарыңыз.",
    introHid: "macOS HID API, Linux hidraw/hidapi және Android USB Host арқылы тікелей байланыс.",
    featuresEyebrow: "Ішінде не бар",
    featuresTitle: "F75 Max үшін арнайы жасалған құралдар.",
    featuresText: "Қолданба сымды операцияларды 2.4G баптауларынан бөледі, сондықтан әр платформада тапсырмаға қай қосылу керек екені анық.",
    featureDisplayTitle: "Пернетақта дисплейі",
    featureDisplayText: "PNG, JPEG, GIF, BMP, TIFF және WebP файлдарын 128 x 128 дисплейге жүктеңіз. Анимациялы GIF кадр кідірістерін сақтайды.",
    featureRgbTitle: "RGB және өнімділік",
    featureRgbText: "Жарық режимін, жарықтықты, жылдамдықты, бағытты, тұрақты түсті, response level және sleep timeout мәндерін баптаңыз.",
    featureBatteryTitle: "Батарея және ескертулер",
    featureBatteryText: "2.4G қабылдағыш арқылы батарея пайызын оқыңыз. Компьютер қолданбалары заряд 20%-дан төмен түскенде де хабарлайды.",
    featureDiagnosticsTitle: "HID диагностикасы",
    featureDiagnosticsText: "Endpoint панелі қосылуды және рұқсаттарды тексеру үшін transport, usage pages және report өлшемдерін көрсетеді.",
    workflowEyebrow: "Жұмыс процесі",
    workflowTitle: "Екі қосылу - екі жауапкершілік аймағы.",
    workflowText: "USB-C дисплей тапсырмалары мен сағатты синхрондау үшін қолданылады. 2.4G қабылдағыш батарея, RGB, жауап, ұйқы және Game Mode үшін қолданылады.",
    workflowItemClock: "Пернетақта сағатын құрылғының жергілікті уақытымен синхрондау.",
    workflowItemReset: "Осы қолданба пайдаланатын display slots және конфигурация блоктары үшін factory reset.",
    workflowItemLogin: "macOS-та Launch at Login және әр платформада интерфейс тілін таңдау.",
    workflowItemLocales: "Android ағылшын және орыс тілдерін, компьютер қолданбалары жеті локализацияны қамтиды.",
    detailsScreenshotAlt: "HID endpoint диагностикасы және қолданба баптаулары",
    installEyebrow: "Орнату",
    installTitle: "DMG, DEB немесе Android APK жүктеңіз.",
    installReadyTitle: "Дайын build",
    installReadyText: "GitHub Releases бетінен macOS DMG, Debian/Ubuntu DEB және болашақ Android релиздеріндегі APK файлын жүктеңіз.",
    installReadyLink: "releases/latest ашу",
    installBuildTitle: "Бастапқы кодтан жинау",
    installBuildText: "Компьютер жинағы Xcode немесе GTK4 және hidapi бар Swift 6 қолданады. Android үшін JDK 17 және Android SDK қажет.",
    installPermissionsTitle: "Платформа рұқсаттары",
    installPermissionsText: "Android 9+ құрылғысын USB OTG арқылы қосып, Grant USB access түймесін басыңыз және рұқсатты растаңыз. macOS Input Monitoring, Linux udev ережесін қолданады.",
    ctaEyebrow: "Ашық код",
    ctaTitle: "Тексеріп, өзіңіз жинай алатын native драйвер.",
    sourceCode: "Бастапқы код",
    footerText: "Epomaker x Aula F75 Max үшін macOS, Linux және Android утилитасы"
  },
  pt: {
    metaDescription: "Aula F75 Max Driver é um utilitário nativo para macOS, Linux e Android que configura o teclado Epomaker x Aula F75 Max, tela, RGB, bateria e modo 2.4G.",
    ogDescription: "Um driver nativo para Aula F75 Max no macOS, Linux e Android: envio para tela, RGB, bateria, Game Mode e diagnóstico HID.",
    navAria: "Navegação principal",
    navFeatures: "Recursos",
    navWorkflow: "Fluxo",
    navInstall: "Instalar",
    languageLabel: "Idioma",
    heroEyebrow: "Utilitário nativo para macOS, Linux e Android",
    heroTitle: "Controle o Aula F75 Max no desktop ou Android.",
    heroText: "Configure a tela do teclado, RGB, bateria, nível de resposta e Game Mode em um app nas três plataformas.",
    downloadDmg: "Baixar release",
    howToInstall: "Como instalar",
    heroFactsAria: "Fatos principais",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "Android 9+ com USB OTG",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Janela principal do Aula F75 Max Driver",
    batteryLabel: "Bateria",
    introDisplay: "Envie imagens e GIFs para a tela do teclado com os modos fit, fill e stretch.",
    introWireless: "Controle bateria, RGB, resposta, suspensão e Game Mode pelo receptor.",
    introHid: "Comunicação direta pelas APIs HID do macOS, Linux hidraw/hidapi e Android USB Host.",
    featuresEyebrow: "O que inclui",
    featuresTitle: "Ferramentas criadas especificamente para o F75 Max.",
    featuresText: "O app separa operações com cabo das configurações 2.4G, deixando claro qual conexão cada tarefa exige em cada plataforma.",
    featureDisplayTitle: "Tela do teclado",
    featureDisplayText: "Envie PNG, JPEG, GIF, BMP, TIFF e WebP para a tela 128 x 128. GIFs animados mantêm os atrasos de quadro.",
    featureRgbTitle: "RGB e desempenho",
    featureRgbText: "Configure modo de iluminação, brilho, velocidade, direção, cor fixa, response level e sleep timeout.",
    featureBatteryTitle: "Bateria e alertas",
    featureBatteryText: "Leia a porcentagem da bateria pelo receptor 2.4G. Os apps desktop também avisam quando ela cai abaixo de 20%.",
    featureDiagnosticsTitle: "Diagnóstico HID",
    featureDiagnosticsText: "O painel de endpoints mostra transporte, usage pages e tamanhos de report para verificar conexão e permissões rapidamente.",
    workflowEyebrow: "Fluxo de trabalho",
    workflowTitle: "Duas conexões, duas áreas de responsabilidade.",
    workflowText: "USB-C é usado para tarefas da tela e sincronização do relógio. O receptor 2.4G é usado para bateria, RGB, resposta, suspensão e Game Mode.",
    workflowItemClock: "Sincronize o relógio do teclado com o horário local do dispositivo.",
    workflowItemReset: "Factory reset para display slots e blocos de configuração usados por este app.",
    workflowItemLogin: "Launch at Login no macOS e seleção do idioma em cada plataforma.",
    workflowItemLocales: "O Android inclui inglês e russo; os apps desktop incluem sete localizações.",
    detailsScreenshotAlt: "Diagnóstico de endpoints HID e configurações do app",
    installEyebrow: "Instalação",
    installTitle: "Baixe um DMG, DEB ou APK para Android.",
    installReadyTitle: "Build pronto",
    installReadyText: "Abra GitHub Releases para obter o DMG para macOS, o DEB para Debian/Ubuntu e o APK em futuras versões do Android.",
    installReadyLink: "Abrir releases/latest",
    installBuildTitle: "Compilar do código-fonte",
    installBuildText: "O desktop usa Xcode ou Swift 6 com GTK4 e hidapi. O Android requer JDK 17 e Android SDK.",
    installPermissionsTitle: "Permissões da plataforma",
    installPermissionsText: "No Android 9+, conecte via USB OTG, toque em Grant USB access e aprove a permissão. O macOS usa Input Monitoring e o Linux uma regra udev.",
    ctaEyebrow: "Código aberto",
    ctaTitle: "Um driver nativo que você pode inspecionar e compilar por conta própria.",
    sourceCode: "Código-fonte",
    footerText: "Utilitário para macOS, Linux e Android compatível com Epomaker x Aula F75 Max"
  },
  "zh-Hans": {
    metaDescription: "Aula F75 Max Driver 是一款原生 macOS、Linux 和 Android 工具，用于配置 Epomaker x Aula F75 Max 键盘、屏幕、RGB 灯效、电池和 2.4G 模式。",
    ogDescription: "面向 Aula F75 Max 的原生 macOS、Linux 和 Android 驱动：屏幕上传、RGB、电池、Game Mode 和 HID 诊断。",
    navAria: "主导航",
    navFeatures: "功能",
    navWorkflow: "流程",
    navInstall: "安装",
    languageLabel: "语言",
    heroEyebrow: "原生 macOS、Linux 和 Android 工具",
    heroTitle: "在桌面系统或 Android 上控制 Aula F75 Max。",
    heroText: "在三种平台上通过一个应用配置键盘屏幕、RGB 灯效、电池状态、响应等级和 Game Mode。",
    downloadDmg: "下载发布版",
    howToInstall: "安装方法",
    heroFactsAria: "关键信息",
    heroFactMac: "macOS 14+",
    heroFactLinux: "Linux GTK4",
    heroFactAndroid: "支持 USB OTG 的 Android 9+",
    heroFactConnections: "USB-C + 2.4G",
    mainScreenshotAlt: "Aula F75 Max Driver 主窗口",
    batteryLabel: "电池",
    introDisplay: "以 fit、fill 和 stretch 模式将图片和 GIF 上传到键盘屏幕。",
    introWireless: "通过接收器控制电池、RGB、响应、睡眠和 Game Mode。",
    introHid: "通过 macOS HID API、Linux hidraw/hidapi 和 Android USB Host 直接通信。",
    featuresEyebrow: "包含内容",
    featuresTitle: "专为 F75 Max 构建的工具。",
    featuresText: "应用将有线操作与 2.4G 设置分开，让每个平台上的任务需要哪种连接一目了然。",
    featureDisplayTitle: "键盘屏幕",
    featureDisplayText: "将 PNG、JPEG、GIF、BMP、TIFF 和 WebP 上传到 128 x 128 屏幕。动态 GIF 会保留帧延迟。",
    featureRgbTitle: "RGB 与性能",
    featureRgbText: "配置灯效模式、亮度、速度、方向、固定颜色、response level 和 sleep timeout。",
    featureBatteryTitle: "电池与提醒",
    featureBatteryText: "通过 2.4G 接收器读取电量百分比。桌面应用还会在电量低于 20% 时发出通知。",
    featureDiagnosticsTitle: "HID 诊断",
    featureDiagnosticsText: "Endpoint 面板显示 transport、usage pages 和 report 大小，便于快速检查连接和权限。",
    workflowEyebrow: "工作流程",
    workflowTitle: "两种连接，两类职责。",
    workflowText: "USB-C 用于屏幕任务和时钟同步。2.4G 接收器用于电池、RGB、响应、睡眠和 Game Mode。",
    workflowItemClock: "将键盘时钟同步到设备本地时间。",
    workflowItemReset: "对本应用使用的 display slots 和配置块执行 factory reset。",
    workflowItemLogin: "macOS 支持 Launch at Login，每个平台均可选择界面语言。",
    workflowItemLocales: "Android 包含英语和俄语；桌面应用包含七种本地化。",
    detailsScreenshotAlt: "HID endpoint 诊断和应用设置",
    installEyebrow: "安装",
    installTitle: "下载 DMG、DEB 或 Android APK。",
    installReadyTitle: "现成构建",
    installReadyText: "打开 GitHub Releases，获取 macOS DMG、Debian/Ubuntu DEB，以及未来 Android 版本中的 APK。",
    installReadyLink: "打开 releases/latest",
    installBuildTitle: "从源码构建",
    installBuildText: "桌面构建使用 Xcode 工具或带 GTK4 和 hidapi 的 Swift 6。Android 构建需要 JDK 17 和 Android SDK。",
    installPermissionsTitle: "平台权限",
    installPermissionsText: "在 Android 9+ 上通过 USB OTG 连接，点击 Grant USB access 并批准权限。macOS 使用 Input Monitoring，Linux 使用 udev 规则。",
    ctaEyebrow: "开源",
    ctaTitle: "一个可以自行检查和构建的原生驱动。",
    sourceCode: "源代码",
    footerText: "面向 Epomaker x Aula F75 Max 的 macOS、Linux 和 Android 工具"
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
