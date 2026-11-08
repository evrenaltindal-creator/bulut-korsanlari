/// All player-facing text, in Turkish and English.
///
/// Every key must exist in both tables; `strings_test.dart` enforces it.
class AppStrings {
  const AppStrings(this.lang);

  final String lang;

  static const supported = ['tr', 'en'];

  String t(String key, [Map<String, Object> args = const {}]) {
    var s = table[lang]?[key] ?? table['en']![key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  static const Map<String, Map<String, String>> table = {'tr': _tr, 'en': _en};
}

const _tr = <String, String>{
  'app.title': 'Bulut Korsanları',
  'app.subtitle': 'Pusula Filosu\'nun seyir defteri',

  'menu.continue': 'Devam et',
  'menu.new': 'Yeni sefer',
  'menu.roster': 'Filo kayıtları',
  'menu.settings': 'Ayarlar',
  'menu.howto': 'Nasıl oynanır',
  'menu.about': 'Hakkında',
  'about.title': 'Bulut Korsanları',
  'about.body':
      'Uçan adalar arasında geçen özgün bir uçuş oyunu. Dünya, hikâye, '
      'karakterler ve bütün çizimler bu oyuna özgüdür. Oyun hiçbir sunucuyla '
      'konuşmaz; kayıtlar yalnızca bu cihazda tutulur.',
  'about.music':
      'Müzik: Google Gemini (Lyria) ile yapay zekâ kullanılarak üretildi; '
      'promptlar bu oyun için yazıldı.',
  'about.sfx':
      'Ses efektleri: OpenGameArt.org\'daki CC0 kayıtlardan (bart, '
      'rubberduck, Nenad Simic) ve kodla üretilen seslerden.',
  'about.art':
      'Hikâye resimleri ve portreler: Google Flow\'da Nano Banana Pro ile '
      'yapay zekâ kullanılarak üretildi; promptlar bu oyun için yazıldı. '
      'Oyun içi çizimler kodla yapılır.',
  'menu.newConfirm': 'Mevcut sefer silinecek. Emin misin?',
  'common.yes': 'Evet',
  'common.cancel': 'Vazgeç',
  'common.close': 'Kapat',

  'intro.title': 'Esinti Takımadası',
  'intro.body':
      'Esinti Takımadası\'nda adalar gökyüzünde süzülür; aralarındaki tek yol '
      'rüzgârdır. Meltem Adası\'nın tüccar zeplinleri yıllardır güvenle '
      'uçuyordu — ta ki Kara Bora korsanları sisin içinden çıkana dek.\n\n'
      'Pusula Filosu\'na yeni katıldın. Komutan Selvi Ardıç seni hangarda '
      'bekliyor.',

  'newPilot.title': 'Yeni pilot',
  'newPilot.name': 'Pilotun adı',
  'newPilot.random': 'Rastgele ad',
  'newPilot.start': 'Filoya katıl',

  'log.day': 'Gün {n}',
  'log.chapter': 'Bölüm {n} · {title}',
  'log.mission': 'Görev {n}/{total}',
  'log.fly': 'Uçuşa çık',
  'log.kind.dogfight': 'İt dalaşı',
  'log.kind.raid': 'Alçak baskın',
  'log.kind.bombing': 'Bombardıman',
  'log.pilot': 'Pilot',
  'log.retry': 'Bu görev yeniden deneniyor.',
  'log.entry.success': '{pilot}: {mission} — başarılı',
  'log.entry.failed': '{pilot}: {mission} — hedef tutturulamadı',
  'log.entry.rescued': '{pilot}: {mission} — düşürüldü, kurtarıldı',
  'log.entry.lost': '{pilot}: {mission} — kayıp',
  'log.diary': 'Seyir defteri',
  'log.diaryEmpty': 'Henüz kayıt yok.',

  'chapter.label': 'Bölüm {n}',
  'chapter.tap': 'Devam etmek için dokun',
  'chapter.1': 'İlk Rüzgâr',
  'chapter.2': 'Kara Bora',
  'chapter.3': 'Fırtınanın Gözü',

  'char.selvi': 'Komutan Selvi Ardıç',
  'char.kerem': 'Usta Kerem',
  'char.surmeli': 'Sürmeli',
  'char.kuzgun': 'Kaptan Kuzgun',
  'brief.officer': 'Brifing',
  'brief.target': 'Hedef',

  'skill.gunnery': 'Nişancılık',
  'skill.handling': 'Pilotaj',
  'stat.kills': 'Düşürülen',
  'stat.missions': 'Uçuş',

  'rank.0': 'Çaylak',
  'rank.1': 'Kanat Eri',
  'rank.2': 'Gözcü Başı',
  'rank.3': 'Yüzbaşı',
  'rank.4': 'As Pilot',

  'm1.title': 'Meyve Bahçeleri Üstünde',
  'm1.brief':
      'Selvi Komutan haritayı masaya yaydı: "İki korsan gözcüsü sabahtan beri '
      'bahçelerin üstünde dolaşıyor, saldırı için yol arıyorlar. Kovala, düşür, '
      'eve dön. Silahlarını fazla ısıtma; tutukluk yaparlarsa kimse seni '
      'kurtaramaz."',
  'm1.win':
      'Gözcülerin enkazı bulut denizine gömüldü. Usta Kerem kanadındaki kurşun '
      'deliklerini sayarken gülümsedi: "Fena değil, çaylak."',
  'm1.lose': 'Gözcüler kaçtı; Kara Bora artık Meltem\'in savunmasını biliyor.',

  'm2.title': 'Çakıl Kayası',
  'm2.brief':
      'Korsanların ikmal deposu Çakıl Kayası adlı küçük bir adada. Alçaktan '
      'gir, sandıkları ve yakıt tanklarını vur; yanan bir tank yanındakileri de '
      'götürür. Vurmak istediğin hedefe dokun: uçak ona döner, menzile girince '
      'kendisi ateş eder. Topçulara dikkat: alçak uçmak isabeti artırır ama '
      'seni onlara da yaklaştırır.',
  'm2.win': 'Çakıl Kayası\'ndan yükselen duman akşama kadar görüldü. Korsanlar bu kış aç kalacak.',
  'm2.lose': 'Deponun çoğu sağlam kaldı. Korsanlar ikmallerini sürdürüyor.',

  'm3.title': 'Kervan',
  'm3.brief':
      'Üç tüccar zeplini Lâle Adası\'na baharat taşıyor. Kara Bora akıncıları '
      'yolu kesmeye geliyor. Akıncılar gözcülerden hızlıdır ve daha sert vurur.',
  'm3.win': 'Kervan Lâle Adası\'na sağ salim vardı. Tüccarlar filoya bir sandık incir gönderdi.',
  'm3.lose': 'Zeplinlerden biri yağmalandı. Tüccarlar korkuyor.',

  'm4.title': 'Kızılkaya Tersanesi',
  'm4.brief':
      'Kara Bora yeni gemilerini Kızılkaya\'daki hangarlarda yapıyor. Üç '
      'hangarı da yık. Nişangâh rüzgârı hesaba katmaz; bombaların '
      'sürüklenmesini sen düzelt. Rüzgâr göstergesi sol üstte.',
  'm4.win':
      'Kızılkaya\'nın hangarları çöktü. Korsan filosu aylarca büyüyemeyecek.',
  'm4.lose': 'Hangarlar ayakta. Yeni korsan gemileri yakında göğe çıkacak.',

  'm5.title': 'Siyah Yelken',
  'm5.brief':
      'Kara Bora\'nın en iyi pilotlarından Sürmeli, siyah yelkenli uçağıyla '
      'devriyede; üç akıncı ona eşlik ediyor. Altın işaretli olan Sürmeli\'dir: '
      'dar döner, keskin nişan alır.',
  'm5.win': 'Siyah yelken alevler içinde bulutlara düştü. Kaptan Kuzgun bunu unutmayacak.',
  'm5.lose': 'Sürmeli hâlâ gökte ve artık filonun adını biliyor.',

  'm6.title': 'Sis Limanı',
  'm6.brief':
      'Kara Bora\'nın gizli limanı bulundu. İskelelere bağlı korsan kayıklarını '
      've depoları vur. Burada topçu çok; alçak ve hızlı geç.',
  'm6.win':
      'İskeleler yanarken korsanlar kayıklarını kurtarmaya çalıştı — boşuna.',
  'm6.lose': 'Liman büyük ölçüde sağlam; korsan kayıkları hâlâ demirli.',

  'm7.title': 'Demir Balina',
  'm7.brief':
      'Zırhlı ikmal zeplini Demir Balina, Kara Bora\'nın amiral gemisine '
      'cephane taşıyor. Hareket hâlinde, nişanını önüne al. Zırhı kalın; '
      'birkaç isabet gerekecek.',
  'm7.win': 'Demir Balina\'nın zırhı yarıldı; yüküyle birlikte bulut denizine gömüldü.',
  'm7.lose':
      'Demir Balina yükünü teslim etti. Amiral gemisi artık tam donanımlı.',

  'm8.title': 'Kaptan Kuzgun',
  'm8.brief':
      'Kaptan Kuzgun bizzat havalandı ve dört akıncıyla Meltem\'e geliyor; '
      'önce akıncılar gelir, kaptan arkadan. '
      'Kaptanı düşürürsen Kara Bora başsız kalır.',
  'm8.win':
      'Kuzgun\'un uçağı paramparça oldu; bir paraşüt sisin içinde kayboldu.',
  'm8.lose': 'Kuzgun yine kaçtı ve öfkesi büyüdü.',

  'm9.title': 'Fırtına Ana',
  'm9.brief':
      'Kara Bora\'nın amiral gemisi Fırtına Ana, kale adasında demirli. Gemiyi '
      've iki hangarı yok et. Uçaksavarlar her yerde. Bu son uçuş; '
      'Takımada\'nın kaderi senin bombalarında.',
  'm9.win':
      'Fırtına Ana alevler içinde sise gömüldü. Kara Bora dağıldı; tüccar '
      'zeplinleri yeniden özgürce uçuyor.',
  'm9.lose':
      'Fırtına Ana hâlâ demirli. Bir sonraki uçuş her şeyi belirleyecek.',

  'debrief.title.success': 'Görev başarılı',
  'debrief.title.objectiveFailed': 'Hedef tutturulamadı',
  'debrief.title.shotDown': 'Düşürüldün',
  'debrief.rescued':
      'Uçağın düştü ama paraşütün açıldı. Bir tüccar zeplini seni bulut '
      'denizinin üstünden topladı.',
  'debrief.lost': '{name} geri dönmedi. Adı hangar duvarına yazıldı.',
  'debrief.newPilot': 'Filoya yeni bir pilot katıldı: {name}.',
  'debrief.promoted': 'Terfi: {rank}',
  'debrief.kills': 'Düşürülen: {n}',
  'debrief.targets': 'Vurulan hedef: {a}/{b}',
  'debrief.accuracy': 'İsabet: %{n}',
  'debrief.gain': '{skill} +{n}',
  'debrief.continue': 'Devam',

  'roster.title': 'Filo kayıtları',
  'roster.active': 'Görevde',
  'roster.lost': 'Kayıp · {mission}',
  'roster.empty': 'Henüz pilot yok.',

  'settings.title': 'Ayarlar',
  'settings.language': 'Dil',
  'settings.music': 'Müzik sesi',
  'settings.sfx': 'Efekt sesi',
  'settings.invert': 'Ters dikey kontrol',
  'settings.invertHint': 'Açıkken çubuğu yukarı itmek burnu aşağı indirir.',

  'howto.title': 'Nasıl oynanır',
  'howto.body':
      'Sol yarı: parmağını koy ve kaydır, uçağı yönlendirir.\n'
      'Sağ yarı: basılı tut, ateş eder; bombardımanda her dokunuş bir bomba '
      'bırakır.\n\n'
      'İt dalaşı: silahlar ısınır; tutukluk olursa soğumasını bekle. Ekran '
      'dışındaki düşmanları kenardaki oklar, hepsini sol üstteki radar '
      'gösterir.\n\n'
      'Alçak baskın: hedefe dokun, uçak ona döner ve menzile girince kendisi '
      'ateş eder; çubukla istediğin an araya girersin. Yukarı/aşağı irtifayı '
      'değiştirir; alçakta mermiler yakına ve daha isabetli düşer.\n\n'
      'Bombardıman: nişangâh rüzgârı hesaba katmaz. Yukarı/aşağı hızı '
      'değiştirir. Çerçeveli hedefler ana hedeflerdir.\n\n'
      'Klavye: ok tuşları veya WASD; Boşluk ateş eder ya da bomba bırakır.',

  'pause.title': 'Duraklatıldı',
  'pause.resume': 'Devam',
  'pause.abandon': 'Görevi bırak',
  'pause.abandonHint': 'Bırakılan görev başarısız sayılır.',

  'hud.hull': 'Gövde',
  'hud.heat': 'Silah ısısı',
  'hud.jammed': 'SİLAH TUTUKLU',
  'hud.enemies': 'Düşman',
  'hud.lowAltitude': 'BULUT DENİZİ — YÜKSEL!',
  'hud.altitude': 'İrtifa',
  'hud.speed': 'Hız',
  'hud.heatGauge': 'Isı',
  'hud.targets': 'Hedef',
  'hud.needed': 'gereken',
  'hud.route': 'Rota',
  'hud.bombs': 'Bomba',
  'hud.primary': 'Ana hedef',
  'hud.wind': 'Rüzgâr',
  'hud.tapTarget': 'Hedefe dokun: uçak ona döner ve kendisi ateş eder',
  'control.fire': 'ATEŞ',
  'control.drop': 'BOMBA',

  'epilogue.title': 'Sefer tamamlandı',
  'epilogue.body':
      'Meltem\'de bayram var. Pusula Filosu\'nun hangarına yeni bir pusula gülü '
      'çizildi; altında bu seferde uçan her pilotun adı yazıyor.',
  'epilogue.stats': '{days} gün · {kills} düşürülen · {pilots} pilot',
};

const _en = <String, String>{
  'app.title': 'Cloud Corsairs',
  'app.subtitle': 'Logbook of the Compass Squadron',

  'menu.continue': 'Continue',
  'menu.new': 'New campaign',
  'menu.roster': 'Squadron records',
  'menu.settings': 'Settings',
  'menu.howto': 'How to play',
  'menu.about': 'About',
  'about.title': 'Cloud Corsairs',
  'about.body':
      'An original flying game set among floating islands. The world, the '
      'story, the characters and all the drawings are made for this game. The '
      'game never talks to a server; saves stay on this device.',
  'about.music':
      'Music: generated with AI using Google Gemini (Lyria), from prompts '
      'written for this game.',
  'about.sfx':
      'Sound effects: CC0 recordings from OpenGameArt.org (bart, rubberduck, '
      'Nenad Simic) and sounds synthesised in code.',
  'about.art':
      'Story paintings and portraits: generated with AI using Nano Banana Pro '
      'in Google Flow, from prompts written for this game. In-game graphics '
      'are drawn in code.',
  'menu.newConfirm': 'Your current campaign will be erased. Are you sure?',
  'common.yes': 'Yes',
  'common.cancel': 'Cancel',
  'common.close': 'Close',

  'intro.title': 'The Breeze Archipelago',
  'intro.body':
      'In the Breeze Archipelago the islands drift through the sky and the '
      'wind is the only road between them. For years the merchant airships of '
      'Meltem Island flew in peace — until the Black Squall pirates came out '
      'of the fog.\n\n'
      'You have just joined the Compass Squadron. Commander Selvi Ardıç is '
      'waiting for you in the hangar.',

  'newPilot.title': 'New pilot',
  'newPilot.name': 'Pilot name',
  'newPilot.random': 'Random name',
  'newPilot.start': 'Join the squadron',

  'log.day': 'Day {n}',
  'log.chapter': 'Chapter {n} · {title}',
  'log.mission': 'Mission {n}/{total}',
  'log.fly': 'Take off',
  'log.kind.dogfight': 'Dogfight',
  'log.kind.raid': 'Low-level raid',
  'log.kind.bombing': 'Bombing run',
  'log.pilot': 'Pilot',
  'log.retry': 'This mission is being flown again.',
  'log.entry.success': '{pilot}: {mission} — success',
  'log.entry.failed': '{pilot}: {mission} — objective missed',
  'log.entry.rescued': '{pilot}: {mission} — shot down, rescued',
  'log.entry.lost': '{pilot}: {mission} — lost',
  'log.diary': 'Logbook',
  'log.diaryEmpty': 'No entries yet.',

  'chapter.label': 'Chapter {n}',
  'chapter.tap': 'Tap to continue',
  'chapter.1': 'First Wind',
  'chapter.2': 'The Black Squall',
  'chapter.3': 'Eye of the Storm',

  'char.selvi': 'Commander Selvi Ardıç',
  'char.kerem': 'Old Kerem',
  'char.surmeli': 'Sürmeli',
  'char.kuzgun': 'Captain Raven',
  'brief.officer': 'Briefing',
  'brief.target': 'Target',

  'skill.gunnery': 'Gunnery',
  'skill.handling': 'Handling',
  'stat.kills': 'Kills',
  'stat.missions': 'Sorties',

  'rank.0': 'Rookie',
  'rank.1': 'Wingman',
  'rank.2': 'Lead Scout',
  'rank.3': 'Captain',
  'rank.4': 'Ace',

  'm1.title': 'Over the Orchards',
  'm1.brief':
      'Commander Selvi spread the map across the table: "Two pirate scouts '
      'have been circling the orchards since dawn, looking for a way in. Chase '
      'them, bring them down, come home. Don\'t let your guns overheat; if '
      'they jam, nobody can save you."',
  'm1.win':
      'The scouts\' wreckage sank into the cloud sea. Old Kerem counted the '
      'bullet holes in your wing and grinned: "Not bad, rookie."',
  'm1.lose':
      'The scouts got away; the Black Squall now knows how Meltem is defended.',

  'm2.title': 'Pebble Rock',
  'm2.brief':
      'The pirates keep their supply cache on a small island called Pebble '
      'Rock. Go in low and hit the crates and fuel tanks; a burning tank takes '
      'its neighbours with it. Tap the target you want: the plane turns to it '
      'and opens fire by itself once it is in range. Watch the gunners: flying '
      'low improves your aim but also brings you closer to them.',
  'm2.win': 'The smoke over Pebble Rock was visible until nightfall. The pirates will go hungry this winter.',
  'm2.lose':
      'Most of the cache survived. The pirates still have their supplies.',

  'm3.title': 'The Caravan',
  'm3.brief':
      'Three merchant airships are carrying spices to Tulip Island. Black '
      'Squall raiders are coming to cut them off. Raiders are faster than '
      'scouts and hit harder.',
  'm3.win': 'The caravan reached Tulip Island safely. The merchants sent the squadron a crate of figs.',
  'm3.lose': 'One of the airships was plundered. The merchants are frightened.',

  'm4.title': 'Redrock Shipyard',
  'm4.brief':
      'The Black Squall builds its new ships in the hangars at Redrock. '
      'Destroy all three hangars. The bombsight does not account for wind; '
      'correct for the drift yourself. The wind gauge is at the top left.',
  'm4.win':
      'Redrock\'s hangars collapsed. The pirate fleet won\'t grow for months.',
  'm4.lose':
      'The hangars still stand. New pirate ships will take to the sky soon.',

  'm5.title': 'The Black Sail',
  'm5.brief':
      'Sürmeli, one of the Black Squall\'s finest pilots, is on patrol in a '
      'black-sailed fighter with three raiders as escort. The one with the '
      'gold marking is Sürmeli: turns tight, shoots straight.',
  'm5.win': 'The black sail fell burning into the clouds. Captain Raven will not forget this.',
  'm5.lose': 'Sürmeli is still flying and now knows the squadron\'s name.',

  'm6.title': 'Fog Harbour',
  'm6.brief':
      'The Black Squall\'s hidden harbour has been found. Strike the pirate '
      'skiffs moored at the docks and the stores. There are many gunners '
      'here; pass low and fast.',
  'm6.win':
      'As the docks burned the pirates tried to save their skiffs — in vain.',
  'm6.lose':
      'The harbour is largely intact; the pirate skiffs are still moored.',

  'm7.title': 'The Iron Whale',
  'm7.brief':
      'The armoured supply airship Iron Whale is carrying ammunition to the '
      'Black Squall\'s flagship. It is moving, so lead your aim. Its plating '
      'is thick; it will take several hits.',
  'm7.win': 'The Iron Whale\'s plating split open and it sank into the cloud sea with its cargo.',
  'm7.lose':
      'The Iron Whale delivered its cargo. The flagship is fully armed now.',

  'm8.title': 'Captain Raven',
  'm8.brief':
      'Captain Raven has taken to the air in person and is flying towards '
      'Meltem with four raiders; the raiders come first and the captain '
      'follows. Bring the captain down and the Black Squall is leaderless.',
  'm8.win': 'Raven\'s plane broke apart; a parachute vanished into the fog.',
  'm8.lose': 'Raven escaped again, angrier than ever.',

  'm9.title': 'Storm Mother',
  'm9.brief':
      'The Black Squall\'s flagship, the Storm Mother, is moored at their '
      'fortress island. Destroy the ship and both hangars. Flak is everywhere. '
      'This is the last flight; the Archipelago\'s fate is in your bombs.',
  'm9.win':
      'The Storm Mother sank burning into the fog. The Black Squall scattered; '
      'the merchant airships fly free again.',
  'm9.lose': 'The Storm Mother is still moored. The next flight will decide everything.',

  'debrief.title.success': 'Mission accomplished',
  'debrief.title.objectiveFailed': 'Objective missed',
  'debrief.title.shotDown': 'Shot down',
  'debrief.rescued':
      'Your plane went down but your parachute opened. A merchant airship '
      'picked you up above the cloud sea.',
  'debrief.lost':
      '{name} did not come back. The name was painted on the hangar wall.',
  'debrief.newPilot': 'A new pilot has joined the squadron: {name}.',
  'debrief.promoted': 'Promoted: {rank}',
  'debrief.kills': 'Kills: {n}',
  'debrief.targets': 'Targets hit: {a}/{b}',
  'debrief.accuracy': 'Accuracy: {n}%',
  'debrief.gain': '{skill} +{n}',
  'debrief.continue': 'Continue',

  'roster.title': 'Squadron records',
  'roster.active': 'On duty',
  'roster.lost': 'Lost · {mission}',
  'roster.empty': 'No pilots yet.',

  'settings.title': 'Settings',
  'settings.language': 'Language',
  'settings.music': 'Music volume',
  'settings.sfx': 'Sound effects',
  'settings.invert': 'Invert vertical control',
  'settings.invertHint': 'When on, pushing the stick up dives.',

  'howto.title': 'How to play',
  'howto.body':
      'Left half: put your thumb down and slide to steer.\n'
      'Right half: hold to fire; on a bombing run every tap drops one bomb.\n\n'
      'Dogfight: guns heat up; if they jam, wait for them to cool. Arrows on '
      'the edge point at enemies off screen, and the radar at the top left '
      'shows them all.\n\n'
      'Low-level raid: tap a target and the plane turns to it and fires by '
      'itself once it is in range; the stick takes over whenever you move it. '
      'Up/down changes altitude; flying low puts your bullets closer and '
      'tighter.\n\n'
      'Bombing run: the sight ignores the wind. Up/down changes speed. Framed '
      'targets are the primary targets.\n\n'
      'Keyboard: arrow keys or WASD; Space fires or drops a bomb.',

  'pause.title': 'Paused',
  'pause.resume': 'Resume',
  'pause.abandon': 'Abandon mission',
  'pause.abandonHint': 'An abandoned mission counts as a failure.',

  'hud.hull': 'Hull',
  'hud.heat': 'Gun heat',
  'hud.jammed': 'GUNS JAMMED',
  'hud.enemies': 'Enemies',
  'hud.lowAltitude': 'CLOUD SEA — PULL UP!',
  'hud.altitude': 'Alt',
  'hud.speed': 'Speed',
  'hud.heatGauge': 'Heat',
  'hud.targets': 'Targets',
  'hud.needed': 'needed',
  'hud.route': 'Route',
  'hud.bombs': 'Bombs',
  'hud.primary': 'Primary',
  'hud.wind': 'Wind',
  'hud.tapTarget': 'Tap a target: the plane turns to it and fires by itself',
  'control.fire': 'FIRE',
  'control.drop': 'BOMB',

  'epilogue.title': 'Campaign complete',
  'epilogue.body':
      'There is a festival on Meltem. A new compass rose has been painted on '
      'the Compass Squadron\'s hangar, and beneath it are the names of every '
      'pilot who flew this campaign.',
  'epilogue.stats': '{days} days · {kills} kills · {pilots} pilots',
};
