# Bulut Korsanları (Cloud Corsairs)

Uçan adalar arasında geçen, hikâyeli bir uçuş oyunu. Flutter + Flame ile
yazıldı; iOS, Android ve web'de çalışır. Tüm görseller kodla çizilir; oyun
hiçbir sunucuyla konuşmaz. Müzik Google Gemini (Lyria) ile üretildi
(künyesi `assets/audio/MUSIC_SOURCE.txt`, promptlar
`docs/audio/music_prompts.md`).

Türü ve görev yapısı 1990'ların seferli uçuş oyunlarından esinlenir
(it dalaşı + alçak baskın + bombardıman, pilot kayıtları), ama dünya,
hikâye, karakterler, uçaklar, haritalar ve çizimler bu projeye özgüdür.

## Oyun

**Esinti Takımadası**'nda adalar gökyüzünde süzülür. Kara Bora korsanları
Meltem Adası'nın tüccar zeplinlerine saldırıyor. Oyuncu Pusula Filosu'na
yeni katılan bir pilottur; sefer üç bölümde dokuz görevden oluşur.

| Görev tipi | Görünüm | Ne yapılır |
| --- | --- | --- |
| **İt dalaşı** | Pilotun arkasından 3B (sözde 3B, kendi projeksiyonu) | Korsan uçaklarını düşür. Silahlar ısınır, tutukluk yapar. Radar ve kenar okları düşmanları gösterir. Bulut denizi zemindir. |
| **Alçak baskın** | İzometrik | Uçan adanın üstünden alçaktan geç, sandık / yakıt tankı / topçu / iskeledeki korsan kayıklarını vur. İrtifa düştükçe nişan yakına ve sıkıya düşer ama topçuya da yaklaşırsın. Yanan tank komşularını da yakar. |
| **Bombardıman** | Tepeden | Nişangâh rüzgârı hesaba katmaz; sürüklenmeyi pilot düzeltir. Hız ayarlanabilir. Çerçeveli hedefler ana hedeflerdir; zırhlı zeplin oyuncudan yavaş, aynı yönde uçar: arkasından yetişip sırtına bomba dizilir. |

**Pilot kaydı:** Her pilotun *nişancılık* ve *pilotaj* yetenekleri vardır;
görev başardıkça gelişir (dağılım daralır, dönüş hızlanır, düşürülünce
paraşütle kurtulma şansı artar). Düşürülen pilot ya kurtarılır ya da kaybolur;
kaybolursa adı kayıtlara yazılır ve yeni bir pilot devralır. Rütbeler:
Çaylak → Kanat Eri → Gözcü Başı → Yüzbaşı → As Pilot.

**Kontroller:** Ekranın sol yarısı yüzen çubuktur (parmağı koy, kaydır).
Sağ yarı ateş / bomba. Klavye: ok tuşları veya WASD, Boşluk. Ayarlar'da dikey
eksen ters çevrilebilir. Dil: Türkçe / İngilizce.

## Geliştirme

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter run            # bağlı cihaz ya da simülatör
flutter run -d chrome  # tarayıcıda
```

Flutter 3.47.1 (Dart 3.13.1) ile geliştirildi ve denendi.

## Yapı

```
lib/
  core/            V3 vektörü, kontrol durumu, efekt listesi (saf Dart)
  game/
    dogfight/      DogfightSim (uçuş modeli, korsan yapay zekâsı, mermiler)
                   Camera3 (perspektif), DogfightPainter (gök, adalar, 3B uçaklar, HUD)
    raid/          RaidSim + RaidPainter (izometrik ada, hedefler, topçu)
    bombing/       BombingSim + BombingPainter (rüzgâr, bombalar, uçaksavar, zeplin)
    mission_game.dart   Flame oyunu: girdi → ControlState → sim → çizim
    touch_controls.dart yüzen çubuk ve ateş bölgesi
  campaign/        görevler, pilot / sefer / günlük, kayıt (SharedPreferences)
  audio/music.dart     müzik yöneticisi: ekranlar arası ve döngüde çapraz geçiş,
                       duraklatmada kısma, arka planda durma
  l10n/strings.dart    tüm metinler (tr + en; anahtarlar test ile eşlenir)
  ui/              menü, seyir defteri, görev ekranı, değerlendirme, kayıtlar
test/              matematik, simülasyonlar, sefer, metinler, widget akışı,
                   otopilotla "her görev kazanılabilir mi" denge testi
```

Simülasyonlar Flutter'a bağımlı değildir; testler onları doğrudan adımlar.
`test/autopilot.dart` her görev tipini kaçınma yapmayan basit bir pilot gibi
uçurur; `balance_test.dart` orta yetenekli bir pilotun dokuz görevin hepsini
kazanabildiğini, aslarınsa çaylak için gerçek tehdit olduğunu bekçiler.
Görev ayarlarını (düşman sayısı, hedefler, rüzgâr, bomba) değiştirirsen bu
testi çalıştır.

## Müzik

Her ekran kendi parçasını `MusicCue` ile ister (`lib/ui/music_cue.dart`);
geri dönülen ekran müziğini yeniden alır. Parçalar
`tool/prepare_music.py` ile hazırlanır: sessizlik kırpılır, ses −16 LUFS'a
eşitlenir, 128 kbit/s sabit bit hızlı MP3'e çevrilir (iOS, Android ve her
tarayıcıda çalar; sabit bit hızı süreyi kesin kılar). Süreler
`MusicTrack` içinde yazılıdır ve test dosya boyutuyla karşılaştırır.
Parça değiştirirsen künyeyi ve süreyi de güncelle.

## Ses efektleri

Makineli tüfek, patlama, uçaksavar, isabet, hasar ve tutukluk
OpenGameArt.org'daki CC0 kayıtlardan `tool/prepare_sfx.py` ile hazırlanır
(tüfek: gerçek bir tam otomatik seriden 8 atımlık dikişsiz döngü). Motor,
bomba ıslığı ve uyarı sesi için CC0 kayıt bulunamadı; onlar
`tool/generate_sfx.py` ile kodla sentezlenir. Kaynaklar
`assets/audio/SFX_SOURCE.txt`'de. Simülasyonlar
olay bildirir (`SimEvent`), `SfxDirector` bunları sese çevirir; motor
perdesi hıza göre değişir, tüfek ateş tuşu basılıyken döner. Ayarlar'da
müzikten ayrı bir efekt sesi var.

## Simge

Kaynak: `assets/branding/app_icon_source.png` (1024×1024, kenara kadar dolu,
saydamlıksız). Nano Banana Pro ile üretilen görselin çizilmiş yuvarlak
karesinden kesildi, köşe dışı iç kenar rengiyle dolduruldu. Bütün
boyutlar şununla üretilir; üretilen dosyaları elle düzenleme:

```bash
python3 tool/generate_app_icon.py assets/branding/app_icon_source.png
```

`--preview <dosya>` simgeyi telefonların gösterdiği gibi (yuvarlak kare,
daire, küçük boyutlar) çizer. Android uyarlanabilir simgede ve web'in
maskelenebilir simgesinde resim küçültülüp kendi kenar rengiyle çevrelenir;
yoksa daire kanat uçlarını ve pusula harflerini keserdi.

## TestFlight (iPhone)

`.github/workflows/ios-testflight.yml` elle başlatılır (Actions → iOS
TestFlight → Run workflow): imzalar, testleri çalıştırır, IPA'yı derler ve
TestFlight'a yükler. Notu `TESTFLIGHT_NOTES.txt`'dir. Paket kimliği
`com.vardiox.bulutkorsanlari`, yalnızca iPhone, yalnızca yatay.

Bir kerelik hazırlık:

1. Depo → Settings → Environments → `testflight` ortamı; gizli değerler:
   `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_IDENTIFIER`,
   `APP_STORE_CONNECT_PRIVATE_KEY` (.p8 dosyasının tamamı),
   `CERTIFICATE_PRIVATE_KEY` (dağıtım sertifikasının RSA anahtarı).
   Değerler depoya ya da sohbete yazılmaz.
2. İş akışı ilk koşuda paket kimliğini Apple'a kaydeder. App Store
   Connect'te uygulama kaydı yoksa durur ve söyler: Uygulamalar → + → Yeni
   Uygulama, bu kimlikle oluşturulur (API bunu yapamaz).
3. TestFlight → Dahili Test → grup (otomatik dağıtım açık), test eden kişi
   eklenir. Sonraki her koşu derlemeyi gruba kendiliğinden düşürür.

Derleme numarası App Store Connect'teki son numaradan bir fazladır; sürüm
adı `pubspec.yaml`'dan gelir.

## Bilinen eksikler

- Gerçek telefonlarda henüz denenmedi; tarayıcıda (Chromium) ve testlerde
  denendi. Müzik ve efektlerin tarayıcıda çaldığı doğrulandı.
- Oyun telefonun sessiz düğmesine uyar: telefon sessizdeyken ses çıkmaz.
- Android paket kimliği `com.vardiox.bulutkorsanlari`; Kotlin ad alanı
  (`namespace`) eski yer tutucu adla kaldı, mağazada görünmez.
