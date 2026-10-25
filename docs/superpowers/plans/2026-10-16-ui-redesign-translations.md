# Sidebar redesign: translation review

Drafted by Claude for owner review. Only rows added by the redesign are listed. pt is Brazilian Portuguese (matches the existing pt.lproj). Edit the values in `Sources/AulaF75MaxDriver/Resources/<lang>.lproj/Localizable.strings`, then run `python3 scripts/checks/check_localization.py`.

Least confident: **kk** and **uz** (checked against nothing). Medium: **zh-Hans**. Most confident: es, pt, ru.

| # | English (key) | es | pt | ru | uz | kk | zh-Hans |
|---|---|---|---|---|---|---|---|
| 1 | Home | Inicio | Início | Главная | Bosh sahifa | Басты бет | 主页 |
| 2 | Lighting | Iluminación | Iluminação | Подсветка | Yoritish | Жарықтандыру | 灯光 |
| 3 | Screen | Pantalla | Tela | Экран | Ekran | Экран | 屏幕 |
| 4 | Settings | Ajustes | Ajustes | Настройки | Sozlamalar | Баптаулар | 设置 |
| 5 | Diagnostics | Diagnóstico | Diagnóstico | Диагностика | Diagnostika | Диагностика | 诊断 |
| 6 | Activity Log | Registro de actividad | Registro de atividade | Журнал действий | Faoliyat jurnali | Әрекеттер журналы | 活动日志 |
| 7 | Advanced | Avanzado | Avançado | Дополнительно | Qoʻshimcha | Қосымша | 高级 |
| 8 | Working… | Trabajando… | Trabalhando… | Выполняется… | Bajarilmoqda… | Орындалуда… | 正在处理… |
| 9 | No activity yet | Sin actividad todavía | Ainda sem atividade | Пока нет действий | Hali faoliyat yoʻq | Әзірге әрекет жоқ | 暂无活动 |
| 10 | Open Activity Log | Abrir registro de actividad | Abrir registro de atividade | Открыть журнал действий | Faoliyat jurnalini ochish | Әрекеттер журналын ашу | 打开活动日志 |
| 11 | Connect the keyboard with a USB-C cable to use these controls. | Conecta el teclado con un cable USB-C para usar estos controles. | Conecte o teclado com um cabo USB-C para usar estes controles. | Подключите клавиатуру кабелем USB-C, чтобы использовать эти элементы. | Bu boshqaruvlardan foydalanish uchun klaviaturani USB-C kabeli bilan ulang. | Бұл басқару элементтерін пайдалану үшін пернетақтаны USB-C кабелімен қосыңыз. | 请使用 USB-C 线连接键盘以使用这些控件。 |
| 12 | Plug in the 2.4G receiver to use these controls. | Conecta el receptor 2.4G para usar estos controles. | Conecte o receptor 2.4G para usar estes controles. | Подключите приёмник 2.4G, чтобы использовать эти элементы. | Bu boshqaruvlardan foydalanish uchun 2.4G qabul qilgichni ulang. | Бұл басқару элементтерін пайдалану үшін 2.4G қабылдағышын қосыңыз. | 请插入 2.4G 接收器以使用这些控件。 |
| 13 | %@ via %@ | %@ vía %@ | %@ via %@ | %@ через %@ | %@ orqali %@ | %@, %@ арқылы | %@，通过 %@ |
| 14 | %d%%  %d/%d | %d%%  %d/%d | %d%%  %d/%d | %d%%  %d/%d | %d%%  %d/%d | %d%%  %d/%d | %d%%  %d/%d |
| 15 | USB cable connected | Cable USB conectado | Cabo USB conectado | Кабель USB подключён | USB kabel ulangan | USB кабелі қосылған | USB 线已连接 |
| 16 | USB cable not connected | Cable USB no conectado | Cabo USB não conectado | Кабель USB не подключён | USB kabel ulanmagan | USB кабелі қосылмаған | USB 线未连接 |
| 17 | 2.4G receiver connected | Receptor 2.4G conectado | Receptor 2.4G conectado | Приёмник 2.4G подключён | 2.4G qabul qilgich ulangan | 2.4G қабылдағышы қосылған | 2.4G 接收器已连接 |
| 18 | 2.4G receiver not connected | Receptor 2.4G no conectado | Receptor 2.4G não conectado | Приёмник 2.4G не подключён | 2.4G qabul qilgich ulanmagan | 2.4G қабылдағышы қосылмаған | 2.4G 接收器未连接 |
| 19 | Refresh battery | Actualizar batería | Atualizar bateria | Обновить заряд | Batareyani yangilash | Батареяны жаңарту | 刷新电量 |
| 20 | Screen clock | Reloj de pantalla | Relógio da tela | Часы на экране | Ekran soati | Экран сағаты | 屏幕时钟 |
| 21 | Set the keyboard clock to this Mac's time | Ajusta el reloj del teclado a la hora de este Mac | Ajusta o relógio do teclado para a hora deste Mac | Установить на клавиатуре время этого Mac | Klaviatura soatini shu Mac vaqtiga moslash | Пернетақта сағатын осы Mac уақытына қою | 将键盘时钟设为此 Mac 的时间 |
| 22 | Needs the USB cable | Requiere el cable USB | Requer o cabo USB | Нужен кабель USB | USB kabel kerak | USB кабелі қажет | 需要 USB 线 |
| 23 | Effects, colour and brightness | Efectos, color y brillo | Efeitos, cor e brilho | Эффекты, цвет и яркость | Effektlar, rang va yorqinlik | Эффектілер, түс және жарықтық | 效果、颜色和亮度 |
| 24 | Open Lighting | Abrir iluminación | Abrir iluminação | Открыть подсветку | Yoritishni ochish | Жарықтандыруды ашу | 打开灯光 |
| 25 | Screen image | Imagen de pantalla | Imagem da tela | Изображение на экране | Ekran rasmi | Экран суреті | 屏幕图片 |
| 26 | Show a picture or GIF on the keyboard display | Muestra una imagen o GIF en la pantalla del teclado | Mostre uma imagem ou GIF na tela do teclado | Показать картинку или GIF на экране клавиатуры | Klaviatura ekranida rasm yoki GIF koʻrsatish | Пернетақта экранында сурет не GIF көрсету | 在键盘屏幕上显示图片或 GIF |
| 27 | Open Screen | Abrir pantalla | Abrir tela | Открыть экран | Ekranni ochish | Экранды ашу | 打开屏幕 |
| 28 | Effect | Efecto | Efeito | Эффект | Effekt | Эффект | 效果 |
| 29 | Colour | Color | Cor | Цвет | Rang | Түс | 颜色 |
| 30 | Rainbow | Arcoíris | Arco-íris | Радуга | Kamalak | Кемпірқосақ | 彩虹 |
| 31 | Single colour | Un solo color | Cor única | Один цвет | Bitta rang | Бір түс | 单色 |
| 32 | Pick a colour | Elige un color | Escolha uma cor | Выберите цвет | Rangni tanlang | Түсті таңдаңыз | 选择颜色 |
| 33 | Changes are sent when you press Apply Lighting. | Los cambios se envían al pulsar Aplicar iluminación. | As alterações são enviadas quando você toca em Aplicar iluminação. | Изменения отправляются при нажатии «Применить подсветку». | Oʻzgarishlar «Yoritishni qoʻllash» bosilganda yuboriladi. | Өзгерістер «Жарықтандыруды қолдану» басылғанда жіберіледі. | 按下“应用灯光”后才会发送更改。 |
| 34 | Apply Lighting | Aplicar iluminación | Aplicar iluminação | Применить подсветку | Yoritishni qoʻllash | Жарықтандыруды қолдану | 应用灯光 |
| 35 | Clock | Reloj | Relógio | Часы | Soat | Сағат | 时钟 |
| 36 | Sets the screen clock to this Mac's time. | Ajusta el reloj de la pantalla a la hora de este Mac. | Ajusta o relógio da tela para a hora deste Mac. | Устанавливает часы экрана по времени этого Mac. | Ekran soatini shu Mac vaqtiga moslaydi. | Экран сағатын осы Mac уақытына қояды. | 将屏幕时钟设为此 Mac 的时间。 |
| 37 | Image | Imagen | Imagem | Изображение | Rasm | Сурет | 图片 |
| 38 | No file selected | Ningún archivo seleccionado | Nenhum arquivo selecionado | Файл не выбран | Fayl tanlanmagan | Файл таңдалмаған | 未选择文件 |
| 39 | Choose File… | Elegir archivo… | Escolher arquivo… | Выбрать файл… | Faylni tanlash… | Файлды таңдау… | 选择文件… |
| 40 | Upload to Keyboard | Subir al teclado | Enviar ao teclado | Загрузить на клавиатуру | Klaviaturaga yuklash | Пернетақтаға жүктеу | 上传到键盘 |
| 41 | Picture | Imagen | Imagem | Картинка | Rasm | Сурет | 图片 |
| 42 | PNG, JPEG, GIF, BMP, TIFF or WebP. Shown at 128 × 128. | PNG, JPEG, GIF, BMP, TIFF o WebP. Se muestra a 128 × 128. | PNG, JPEG, GIF, BMP, TIFF ou WebP. Exibida em 128 × 128. | PNG, JPEG, GIF, BMP, TIFF или WebP. Показывается в 128 × 128. | PNG, JPEG, GIF, BMP, TIFF yoki WebP. 128 × 128 oʻlchamda koʻrsatiladi. | PNG, JPEG, GIF, BMP, TIFF немесе WebP. 128 × 128 өлшемде көрсетіледі. | 支持 PNG、JPEG、GIF、BMP、TIFF 或 WebP。以 128 × 128 显示。 |
| 43 | Key response | Respuesta de teclas | Resposta das teclas | Отклик клавиш | Tugmalar javobi | Пернелер жауабы | 按键响应 |
| 44 | Sleep after | Suspender tras | Suspender após | Сон через | Uyquga ketish | Ұйқы режимі | 休眠时间 |
| 45 | Typing | Escritura | Digitação | Набор текста | Yozish | Теру | 打字 |
| 46 | Changes are sent when you press Apply. | Los cambios se envían al pulsar Aplicar. | As alterações são enviadas quando você toca em Aplicar. | Изменения отправляются при нажатии «Применить». | Oʻzgarishlar «Qoʻllash» bosilganda yuboriladi. | Өзгерістер «Қолдану» басылғанда жіберіледі. | 按下“应用”后才会发送更改。 |
| 47 | Restore Command Key | Restaurar tecla Comando | Restaurar tecla Command | Восстановить клавишу Command | Command tugmasini tiklash | Command пернесін қалпына келтіру | 恢复 Command 键 |
| 48 | Game Mode | Modo juego | Modo jogo | Игровой режим | Oʻyin rejimi | Ойын режимі | 游戏模式 |
| 49 | Locks the Command (⌘) key so it can't interrupt games. Also sends the Typing settings above. | Bloquea la tecla Comando (⌘) para que no interrumpa los juegos. También envía los ajustes de Escritura de arriba. | Bloqueia a tecla Command (⌘) para não interromper jogos. Também envia os ajustes de Digitação acima. | Блокирует клавишу Command (⌘), чтобы она не мешала в играх. Также отправляет настройки набора выше. | Oʻyinlarga xalaqit bermasligi uchun Command (⌘) tugmasini qulflaydi. Yuqoridagi Yozish sozlamalarini ham yuboradi. | Ойынға кедергі болмауы үшін Command (⌘) пернесін құлыптайды. Жоғарыдағы Теру баптауларын да жібереді. | 锁定 Command (⌘) 键，避免打断游戏。同时会发送上方的打字设置。 |
| 50 | General | General | Geral | Основные | Umumiy | Жалпы | 通用 |
| 51 | Opens the app when you log in. Works without the keyboard connected. | Abre la app al iniciar sesión. Funciona sin el teclado conectado. | Abre o app ao iniciar a sessão. Funciona sem o teclado conectado. | Открывает приложение при входе в систему. Работает без подключённой клавиатуры. | Tizimga kirganda ilovani ochadi. Klaviatura ulanmagan holda ham ishlaydi. | Жүйеге кіргенде қолданбаны ашады. Пернетақта қосылмаса да жұмыс істейді. | 登录时打开应用。无需连接键盘。 |
| 52 | Danger Zone | Zona de peligro | Zona de perigo | Опасная зона | Xavfli hudud | Қауіпті аймақ | 危险操作 |
| 53 | Clears uploaded screen images and resets keyboard settings changed by this app. | Borra las imágenes subidas a la pantalla y restablece los ajustes del teclado cambiados por esta app. | Apaga as imagens enviadas à tela e redefine os ajustes do teclado alterados por este app. | Удаляет загруженные на экран изображения и сбрасывает настройки клавиатуры, изменённые этим приложением. | Ekranga yuklangan rasmlarni oʻchiradi va ushbu ilova oʻzgartirgan klaviatura sozlamalarini tiklaydi. | Экранға жүктелген суреттерді өшіреді және осы қолданба өзгерткен пернетақта баптауларын қалпына келтіреді. | 清除已上传的屏幕图片，并重置此应用更改过的键盘设置。 |
| 54 | Factory Reset Keyboard… | Restablecer teclado de fábrica… | Restaurar teclado de fábrica… | Сбросить клавиатуру к заводским… | Klaviaturani zavod sozlamalariga qaytarish… | Пернетақтаны зауыттық баптауларға қайтару… | 将键盘恢复出厂设置… |
| 55 | Connections | Conexiones | Conexões | Подключения | Ulanishlar | Қосылымдар | 连接 |
| 56 | Logs raw HID input reports (key presses, knob clicks) to the log below. | Registra los informes HID sin procesar (pulsaciones, clics de la rueda) en el registro de abajo. | Registra relatórios HID brutos (teclas, cliques do botão giratório) no registro abaixo. | Записывает сырые HID-отчёты (нажатия клавиш, щелчки ручки) в журнал ниже. | Xom HID hisobotlarini (tugma bosish, gʻildirak bosish) quyidagi jurnalga yozadi. | Өңделмеген HID есептерін (перне басу, тұтқа шерту) төмендегі журналға жазады. | 将原始 HID 输入报告（按键、旋钮点击）记录到下方日志。 |
| 57 | Keymap Research | Investigación del mapa de teclas | Pesquisa do mapa de teclas | Исследование раскладки | Tugmalar xaritasini tadqiq qilish | Пернелер картасын зерттеу | 键位映射研究 |
| 58 | For protocol research. Not needed for normal use. The test write sets one byte in one page and zeros the rest of all 9 pages. | Para investigar el protocolo. No es necesario en el uso normal. La escritura de prueba fija un byte en una página y pone a cero el resto de las 9 páginas. | Para pesquisa do protocolo. Não é necessário no uso normal. A gravação de teste define um byte em uma página e zera o resto das 9 páginas. | Для исследования протокола. В обычной работе не нужно. Тестовая запись задаёт один байт на одной странице и обнуляет остальное на всех 9 страницах. | Protokolni tadqiq qilish uchun. Oddiy foydalanishda kerak emas. Sinov yozuvi bitta sahifada bitta baytni oʻrnatadi va 9 sahifaning qolganini nolga tenglaydi. | Протоколды зерттеуге арналған. Қалыпты пайдалануда қажет емес. Сынақ жазбасы бір беттегі бір байтты орнатады да, 9 беттің қалғанын нөлге теңейді. | 用于协议研究，日常使用无需操作。测试写入会在某一页设置一个字节，并将全部 9 页的其余部分清零。 |
| 59 | Write Test Byte… | Escribir byte de prueba… | Gravar byte de teste… | Записать тестовый байт… | Sinov baytini yozish… | Сынақ байтын жазу… | 写入测试字节… |
| 60 | Write to the keyboard? | ¿Escribir en el teclado? | Gravar no teclado? | Записать на клавиатуру? | Klaviaturaga yozilsinmi? | Пернетақтаға жазу керек пе? | 要写入键盘吗？ |
| 61 | This changes keymap data on the keyboard. Factory Reset can undo it. | Esto cambia los datos del mapa de teclas. El restablecimiento de fábrica puede deshacerlo. | Isto altera os dados do mapa de teclas. A restauração de fábrica pode desfazer. | Это изменит данные раскладки на клавиатуре. Сброс к заводским настройкам может это отменить. | Bu klaviaturadagi tugmalar xaritasi maʼlumotlarini oʻzgartiradi. Zavod sozlamalariga qaytarish buni bekor qila oladi. | Бұл пернетақтадағы пернелер картасының деректерін өзгертеді. Зауыттық баптауларға қайтару мұны болдырмауы мүмкін. | 这会更改键盘上的键位映射数据。恢复出厂设置可以撤销。 |
| 62 | Write | Escribir | Gravar | Записать | Yozish | Жазу | 写入 |
| 63 | Copy Log | Copiar registro | Copiar registro | Копировать журнал | Jurnalni nusxalash | Журналды көшіру | 复制日志 |
| 64 | Copy the whole log to the clipboard | Copia todo el registro al portapapeles | Copia todo o registro para a área de transferência | Скопировать весь журнал в буфер обмена | Butun jurnalni almashuv buferiga nusxalash | Бүкіл журналды алмасу буферіне көшіру | 将完整日志复制到剪贴板 |
| 65 | Byte | Byte | Byte | Байт | Bayt | Байт | 字节 |
| 66 | Page | Página | Página | Страница | Sahifa | Бет | 页 |
| 67 | Length | Longitud | Comprimento | Длина | Uzunlik | Ұзындық | 长度 |
| 68 | Value | Valor | Valor | Значение | Qiymat | Мән | 值 |
| 69 | Keymap inspector | Inspector del mapa de teclas | Inspetor do mapa de teclas | Просмотр раскладки | Tugmalar xaritasi koʻruvchisi | Пернелер картасын қарау | 键位映射检查器 |
| 70 | Dump Keymap Pages | Volcar páginas del mapa de teclas | Exportar páginas do mapa de teclas | Выгрузить страницы раскладки | Tugmalar xaritasi sahifalarini chiqarish | Пернелер картасы беттерін шығару | 导出键位映射页 |
| 71 | Start Input Monitor | Iniciar monitor de entrada | Iniciar monitor de entrada | Запустить монитор ввода | Kiritish monitorini boshlash | Енгізу мониторын бастау | 开始输入监视 |
| 72 | Stop Input Monitor | Detener monitor de entrada | Parar monitor de entrada | Остановить монитор ввода | Kiritish monitorini toʻxtatish | Енгізу мониторын тоқтату | 停止输入监视 |
