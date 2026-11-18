# App Store metadata: localized listings

**These listings are the text for version 1.1.0 (export packs and Premium).** The 1.0.0 text, which is in review with no in-app purchases, is kept unchanged in `v1.0-in-review/metadata-localized.md`. Nothing here is pasted into App Store Connect until 1.1.0 is released. The in-app purchase names and descriptions for each language are in `../EXPORT-GATE-IOS.md`.

Localized App Store Connect listings for Spanish (Spain), French (France), German and Chinese (Simplified). The English (U.S.) listing, category, age rating, URLs, review notes and screenshot rules are in `metadata.md` and apply unchanged to every language here. The app UI and the document language picker already ship in all five languages (English, Español, Français, Deutsch, 简体中文).

Limits are checked by `python design/check_store_metadata.py`, together with the English file. Structure: every field is a heading `## <locale> > <Field>` followed by exactly one fenced block. The script reads the first fenced block under each heading, so keep one block per field and re-run it after any edit. Apple counts characters (not bytes) for every field, including Chinese.

Fields per locale: App Name (30), Subtitle (30), Keywords (100, comma separated, no spaces, no words already in the name or subtitle, no trademarks), Promotional Text (170), Description (4000), Screenshot Captions (6 lines, at most 5 words each; Chinese at most 12 characters). What's New and review notes are not localized: App Store Connect shows the English What's New where a locale leaves it empty, and review notes are read by Apple in English.

Screenshot captions, line by line, match these English shots in `metadata.md`: line 1 = shot 1 "Build a polished resume", line 2 = shot 2 "30 templates to choose from", line 3 = shot 3 "Change every detail", line 4 = shot 5 "Cover letters that match", line 5 = shot 6 "Check your layout", line 6 = shot 8 "Share or save as PDF". Shots 4 and 7 keep their English caption only if all eight are uploaded; otherwise upload six screenshots per locale. Captions never mention price.

Reusing es-ES for Mexico (es-MX): the copy uses tú and neutral vocabulary, so it can be pasted into the es-MX listing as is. Only one change reads more naturally for Mexico: "vídeo" becomes "video" (Description and nowhere else). The name, subtitle and keywords work for both.

---

## es-ES > App Name

```
Currículum y CV: CareerKit
```

## es-ES > Subtitle

```
Crea tu CV con 30 plantillas
```

## es-ES > Keywords

```
hacer,carta,presentación,vitae,empleo,trabajo,pdf,docx,ats,oferta,entrevista,estudiante,modelo
```

## es-ES > Promotional Text

```
Elige entre 30 plantillas, importa tu currículum anterior, compáralo con una oferta de empleo y expórtalo a PDF o Word. Tus documentos se quedan en tu dispositivo.
```

## es-ES > Description

```
Currículum y CV: CareerKit te ayuda a crear un currículum claro y bien presentado, junto con su carta de presentación, en tu iPhone o iPad. Elige una plantilla, escribe tus datos, mira cómo se actualiza la página y exporta a PDF o Word cuando lo tengas listo.

QUÉ INCLUYE

30 plantillas de currículum en seis grupos: Profesional, Moderno, Creativo, Académico, Nivel inicial y Técnico. Hay diseños de una columna, con barra lateral a la izquierda o a la derecha y con cabecera de color.

Muchas plantillas tienen un espacio para una foto opcional, en la cabecera o en la barra lateral. Si prefieres un currículum sin foto, solo tienes que no añadirla.

Un currículum en blanco, por si prefieres empezar de cero y elegir tú cada sección.

Control total de los detalles: añade, oculta y reordena secciones, y cambia el color de acento, las fuentes, el tamaño del texto, el interlineado y los márgenes.

10 plantillas de carta de presentación con el mismo estilo que tu currículum, para que los dos documentos combinen.

Una revisión ATS que lee tu currículum y te da consejos generales sobre títulos, datos de contacto, fechas, diseño y extensión. Son solo consejos. No es una puntuación del sistema de ninguna empresa y no puede prometer ningún resultado.

Varios currículums en un mismo sitio. Guarda una versión para cada tipo de puesto, duplícalas, cámbiales el nombre o archívalas, y compara dos versiones una al lado de la otra.

Tamaño de página A4 o US Letter.

EXPORTA COMO QUIERAS: PDF con texto seleccionable, Word (.docx), texto enriquecido, texto sin formato para formularios en línea o página web. Comparte el archivo, guárdalo en Archivos o imprime el PDF. Con la copia de seguridad guardas todo en un solo archivo que puedes conservar donde quieras.

IMPORTA TU CURRÍCULUM ANTERIOR: abre un PDF o pega el texto, revisa lo que se ha encontrado sección por sección y sigue editando en la plantilla que más te guste. Los PDF con texto funcionan mejor. Las páginas escaneadas no se leen.

PALABRAS CLAVE DE UNA OFERTA: pega una oferta de empleo y comprueba qué términos clave ya aparecen en tu currículum y cuáles faltan. Es una ayuda para leer la oferta, no una puntuación. Añade solo lo que sea cierto en tu caso.

EN TU IDIOMA: la app está en español, inglés, francés, alemán y chino simplificado. Puedes escribir cada currículum y cada carta en cualquiera de estos idiomas, sea cual sea el idioma de tu iPhone.

Escribir, editar y ver la vista previa funciona sin conexión. No necesitas crear una cuenta, y tus currículums y cartas se guardan solo en tu dispositivo.

GRATIS, CON ANUNCIOS Y COMPRAS OPCIONALES

Escribir, editar, ver la vista previa, las cartas de presentación y la revisión ATS son gratis, sin límite y sin anuncios.

Guardar, compartir o imprimir un documento terminado usa una exportación. Puedes comprar un paquete de 3 exportaciones, comprar Premium (un solo pago, sin suscripción, exportaciones ilimitadas) o ver un vídeo corto con recompensa para exportar un documento una vez, con 24 horas de validez. La App Store muestra el precio antes de comprar. Los paquetes usados no se pueden restaurar.

La app también se financia con anuncios de Google AdMob. Puede aparecer un banner en pantallas de navegación como Inicio, Mis currículums, Plantillas, Cartas y Perfil. Nunca hay anuncios en el editor ni en la vista previa. Premium no elimina los banners.

Donde la ley lo exige, la app te pide tu consentimiento antes de mostrar anuncios personalizados, y puedes cambiar tu elección más adelante en la pestaña Perfil.

TUS DATOS

El contenido de tu currículum nunca sale de tu dispositivo. CareerKit no tiene sistema de cuentas y no sube lo que escribes. Puedes eliminar todos tus datos desde la pestaña Perfil.

¿Dudas o ideas? Visita https://ecomswiftllc.github.io/careerkit/support/ o escribe a support@ecomswiftllc.com.
```

## es-ES > Screenshot Captions

```
Crea un currículum cuidado
30 plantillas para elegir
Cambia cada detalle
Cartas a juego
Revisa tu diseño
Comparte o guarda en PDF
```

---

## fr-FR > App Name

```
Créateur de CV : CareerKit
```

## fr-FR > Subtitle

```
Modèles, lettre de motivation
```

## fr-FR > Keywords

```
curriculum,vitae,créer,rédiger,emploi,candidature,pdf,docx,ats,entretien,étudiant,stage,offre
```

## fr-FR > Promotional Text

```
Choisissez parmi 30 modèles, importez votre ancien CV, comparez-le à une offre d'emploi, puis exportez-le en PDF ou Word. Vos documents restent sur votre appareil.
```

## fr-FR > Description

```
Créateur de CV : CareerKit vous aide à réaliser un CV clair et bien mis en page, ainsi que votre lettre de motivation, sur iPhone ou iPad. Choisissez un modèle, saisissez vos informations, regardez la page se mettre à jour, puis exportez en PDF ou Word quand vous êtes prêt.

CE QUE VOUS TROUVEREZ

30 modèles de CV répartis en six familles : Professionnel, Moderne, Créatif, Académique, Débutant et Technique. Les mises en page vont de la colonne unique à la barre latérale à gauche ou à droite, en passant par l'en-tête en bandeau.

De nombreux modèles prévoient un emplacement pour une photo facultative, dans l'en-tête ou dans la barre latérale. Pour un CV sans photo, il suffit de ne pas en ajouter.

Un CV vierge, si vous préférez partir de zéro et choisir vous-même chaque rubrique.

La maîtrise de chaque détail : ajoutez, masquez et réorganisez les rubriques, et modifiez la couleur d'accent, les polices, la taille du texte, l'interligne et les marges.

10 modèles de lettre de motivation assortis à votre CV, pour que les deux documents forment un ensemble cohérent.

Une vérification ATS qui lit votre CV et donne des conseils généraux sur les titres, les coordonnées, les dates, la mise en page et la longueur. Il s'agit uniquement de conseils. Ce n'est pas une note issue du système d'un employeur et elle ne peut garantir aucun résultat.

Plusieurs CV au même endroit. Gardez une version pour chaque type de poste, dupliquez-les, renommez-les ou archivez-les, et comparez deux versions côte à côte.

Format de page A4 ou US Letter.

EXPORTEZ À VOTRE FAÇON : PDF avec texte sélectionnable, Word (.docx), texte enrichi, texte brut pour les formulaires en ligne, ou page web. Partagez le fichier, enregistrez-le dans Fichiers ou imprimez le PDF. La sauvegarde enregistre une copie de tout votre contenu dans un seul fichier, à conserver où vous voulez.

IMPORTEZ VOTRE ANCIEN CV : ouvrez un PDF ou collez le texte, vérifiez rubrique par rubrique ce qui a été reconnu, puis poursuivez dans le modèle de votre choix. Les PDF contenant du texte donnent les meilleurs résultats. Les pages numérisées ne sont pas lues.

MOTS-CLÉS D'UNE OFFRE : collez une offre d'emploi et voyez quels termes importants votre CV contient déjà et lesquels manquent. C'est une aide à la lecture, pas une note. N'ajoutez que ce qui vous correspond vraiment.

DANS VOTRE LANGUE : l'app est disponible en français, anglais, espagnol, allemand et chinois simplifié. Chaque CV et chaque lettre peut être rédigé dans l'une de ces langues, quelle que soit la langue de votre iPhone.

La rédaction, la modification et l'aperçu fonctionnent hors ligne. Aucun compte à créer : vos CV et vos lettres sont stockés uniquement sur votre appareil.

GRATUIT, AVEC PUBLICITÉ ET ACHATS FACULTATIFS

La rédaction, la modification, l'aperçu, les lettres de motivation et la vérification ATS sont gratuits, sans limite et sans publicité.

Enregistrer, partager ou imprimer un document terminé utilise un export. Choisissez un pack de 3 exports, Premium (achat unique, sans abonnement, exports illimités) ou une courte vidéo avec récompense pour exporter un document une fois (24 h). L'App Store affiche le prix avant l'achat. Les packs utilisés ne sont pas restaurables.

L'app est aussi financée par des publicités Google AdMob. Une bannière peut s'afficher sur les écrans de navigation (Accueil, Mes CV, Modèles, Lettres, Profil), jamais dans l'éditeur ni l'aperçu. Premium ne supprime pas les bannières.

Là où la loi l'exige, l'app vous demande votre consentement avant d'afficher des publicités personnalisées, et vous pouvez modifier votre choix plus tard dans l'onglet Profil.

VOS DONNÉES

Le contenu de votre CV ne quitte jamais votre appareil. CareerKit n'a pas de système de comptes et n'envoie pas ce que vous écrivez. Vous pouvez supprimer toutes vos données depuis l'onglet Profil.

Une question ou une idée ? Rendez-vous sur https://ecomswiftllc.github.io/careerkit/support/ ou écrivez à support@ecomswiftllc.com.
```

## fr-FR > Screenshot Captions

```
Un CV soigné et clair
30 modèles au choix
Personnalisez chaque détail
Des lettres assorties
Vérifiez votre mise en page
Partagez ou enregistrez en PDF
```

---

## de-DE > App Name

```
Lebenslauf & CV: CareerKit
```

## de-DE > Subtitle

```
Vorlagen und Anschreiben
```

## de-DE > Keywords

```
bewerbung,erstellen,muster,curriculum,vitae,pdf,docx,ats,stellenanzeige,student,job,berufseinstieg
```

## de-DE > Promotional Text

```
30 Vorlagen, Import des alten Lebenslaufs, Abgleich mit einer Stellenanzeige und Export als PDF oder Word. Funktioniert offline, die Dokumente bleiben auf dem Gerät.
```

## de-DE > Description

```
Lebenslauf & CV: CareerKit hilft dabei, auf iPhone oder iPad einen klaren, sauber gestalteten Lebenslauf und das passende Anschreiben zu erstellen. Vorlage wählen, Daten eintragen, die Seite aktualisiert sich sofort, und wenn alles fertig ist, als PDF oder Word exportieren.

DAS IST ENTHALTEN

30 Lebenslauf-Vorlagen in sechs Gruppen: Professionell, Modern, Kreativ, Akademisch, Einstieg und Technik. Zur Wahl stehen einspaltige Layouts, Seitenleisten links oder rechts und Kopfzeilen als farbiges Band.

Viele Vorlagen bieten Platz für ein optionales Bewerbungsfoto, im Kopfbereich oder in der Seitenleiste. Wer keinen Lebenslauf mit Foto möchte, fügt einfach keines hinzu.

Ein leerer Lebenslauf für alle, die bei null beginnen und jeden Abschnitt selbst auswählen möchten.

Volle Kontrolle über die Details: Abschnitte hinzufügen, ausblenden und neu anordnen, dazu Akzentfarbe, Schriften, Textgröße, Zeilenabstand und Ränder anpassen.

10 Vorlagen für Anschreiben im Stil des Lebenslaufs, damit beide Dokumente zusammenpassen.

Eine ATS-Prüfung, die den Lebenslauf liest und allgemeine Hinweise zu Überschriften, Kontaktdaten, Datumsangaben, Layout und Länge gibt. Es handelt sich nur um Hinweise. Das ist keine Bewertung aus dem System eines Arbeitgebers, und ein bestimmtes Ergebnis lässt sich damit nicht versprechen.

Mehrere Lebensläufe an einem Ort. Für jede Art von Stelle eine eigene Version anlegen, Versionen duplizieren, umbenennen oder archivieren und zwei Versionen nebeneinander vergleichen.

Seitenformat A4 oder US Letter.

EXPORT NACH WUNSCH: PDF mit markierbarem Text, Word (.docx), Rich Text, reiner Text für Onlineformulare oder Webseite. Datei teilen, in „Dateien“ sichern oder das PDF drucken. Eine Sicherung speichert alles in einer einzigen Datei, die sich überall aufbewahren lässt.

ALTEN LEBENSLAUF IMPORTIEREN: ein PDF öffnen oder den Text einfügen, Abschnitt für Abschnitt prüfen, was erkannt wurde, und in einer Vorlage nach Wahl weiterarbeiten. PDFs mit echtem Text funktionieren am besten. Gescannte Seiten werden nicht gelesen.

SCHLÜSSELWÖRTER AUS DER STELLENANZEIGE: eine Stellenanzeige einfügen und sehen, welche wichtigen Begriffe der Lebenslauf schon enthält und welche fehlen. Das ist eine Lesehilfe, keine Bewertung. Nur ergänzen, was auch wirklich zutrifft.

IN IHRER SPRACHE: Die App gibt es auf Deutsch, Englisch, Spanisch, Französisch und vereinfachtem Chinesisch. Jeder Lebenslauf und jedes Anschreiben lässt sich in einer dieser Sprachen verfassen, unabhängig von der Sprache des iPhone.

Schreiben, Bearbeiten und Vorschau funktionieren offline. Es ist kein Konto nötig, und Lebensläufe und Anschreiben werden nur auf dem Gerät gespeichert.

KOSTENLOS, MIT WERBUNG UND OPTIONALEN KÄUFEN

Schreiben, Bearbeiten, Vorschau, Anschreiben und die ATS-Prüfung sind kostenlos, ohne Limit und ohne Werbung.

Ein fertiges Dokument zu speichern, zu teilen oder zu drucken verbraucht einen Export. Sie können ein Paket mit 3 Exporten kaufen, Premium kaufen (einmaliger Kauf, kein Abo, unbegrenzte Exporte) oder ein kurzes Video mit Belohnung ansehen und ein Dokument einmal exportieren, 24 Stunden gültig. Der App Store zeigt den Preis vor dem Kauf an. Verbrauchte Pakete lassen sich nicht wiederherstellen.

Außerdem finanziert sich die App über Werbung von Google AdMob. Auf Übersichtsseiten wie Start, Meine Lebensläufe, Vorlagen, Anschreiben und Profil kann ein Werbebanner erscheinen, nie im Editor oder in der Vorschau. Premium entfernt die Banner nicht.

Wo es gesetzlich vorgeschrieben ist, fragt die App vor personalisierter Werbung nach Ihrer Einwilligung. Die Auswahl lässt sich später im Tab Profil ändern.

IHRE DATEN

Der Inhalt des Lebenslaufs verlässt das Gerät nie. CareerKit hat kein Kontosystem und lädt nichts von dem hoch, was Sie schreiben. Alle Daten lassen sich im Tab Profil löschen.

Fragen oder Ideen? Besuchen Sie https://ecomswiftllc.github.io/careerkit/support/ oder schreiben Sie an support@ecomswiftllc.com.
```

## de-DE > Screenshot Captions

```
Ihr Lebenslauf, sauber gestaltet
30 Vorlagen zur Auswahl
Jedes Detail anpassen
Passende Anschreiben
Layout prüfen
Als PDF teilen oder sichern
```

---

## zh-Hans > App Name

```
简历制作与求职信：CareerKit
```

## zh-Hans > Subtitle

```
30款模板，支持导出PDF
```

## zh-Hans > Keywords

```
履历,找工作,应聘,面试,自荐信,cv,ats,关键词,毕业生,实习,招聘,职位,排版,文档,工作经历,docx,个人资料
```

## zh-Hans > Promotional Text

```
从 30 款模板中选择，导入旧简历，对照招聘信息检查关键词，再导出为 PDF 或 Word。可离线使用，你的文档只保存在你的设备上。
```

## zh-Hans > Description

```
简历制作与求职信：CareerKit 帮你在 iPhone 或 iPad 上制作清晰、排版规整的简历和求职信。选择模板，填写信息，页面会随时更新，完成后即可导出为 PDF 或 Word。

主要功能

30 款简历模板，分为六类：专业、现代、创意、学术、入门级和技术。版式包括单栏、左侧或右侧边栏，以及横幅式页眉。

许多模板都留有可选照片的位置，放在页眉或边栏中。如果不想放照片，不添加即可。

空白简历：想从零开始、自己挑选每个板块时使用。

细节全由你掌控：添加、隐藏和调整板块顺序，更改强调色、字体、字号、行距和页边距。

10 款求职信模板，与简历风格一致，两份文档看起来是一套。

ATS 检查：读取你的简历，就标题、联系方式、日期、版式和篇幅给出一般性建议。这些只是建议，不是任何雇主系统给出的评分，也无法保证任何结果。

多份简历集中管理。为不同类型的职位各保存一个版本，可复制、重命名或归档，还能并排比较两个版本。

页面尺寸可选 A4 或 US Letter。

多种导出格式：可选中文字的 PDF、Word (.docx)、RTF 富文本、适合在线表单的纯文本，或网页。可以分享文件、存储到“文件”或打印 PDF。备份功能会把所有内容保存到一个文件中，你可以把它放在任何地方。

导入旧简历：打开 PDF 或粘贴文本，逐个板块检查识别结果，然后在喜欢的模板中继续编辑。含文字的 PDF 效果最好，扫描页面无法读取。

招聘信息关键词检查：粘贴一则招聘信息，看看其中的关键词哪些已经出现在你的简历中，哪些还没有。这只是阅读辅助，不是评分。请只添加符合你真实情况的内容。

支持多种语言：应用提供简体中文、英语、西班牙语、法语和德语界面。每份简历和求职信都可以用其中任意一种语言撰写，与 iPhone 的系统语言无关。

撰写、编辑和预览均可离线使用。无需注册账户，你的简历和求职信只保存在你的设备上。

免费使用，含广告和可选内购

撰写、编辑、预览、求职信和 ATS 检查都是免费的，没有次数限制，也不需要看广告。

保存、分享或打印一份已完成的文档会用掉一次导出。你可以购买 3 次导出包，购买 Premium（一次性购买，不是订阅，不限次数导出），或观看一段简短的激励视频，导出该文档一次，24 小时内有效。购买前 App Store 会显示价格。已用完的导出包无法恢复。

应用同时通过 Google AdMob 广告维持运营。首页、我的简历、模板、求职信和个人资料等浏览页面可能会显示横幅广告。编辑器和预览中没有广告。Premium 不会去掉横幅广告。

在法律有要求的地区，应用会在展示个性化广告前征求你的同意，之后你可以在“个人资料”标签中更改选择。

你的数据

你的简历内容不会离开你的设备。CareerKit 没有账户系统，也不会上传你写的内容。你可以在“个人资料”标签中删除所有数据。

有问题或建议？请访问 https://ecomswiftllc.github.io/careerkit/support/ 或发送邮件至 support@ecomswiftllc.com。
```

## zh-Hans > Screenshot Captions

```
打造精致简历
30 款模板任你选
每个细节都可调整
配套的求职信
检查简历排版
分享或存储为 PDF
```
