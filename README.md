# Bulut Korsanları (Cloud Corsairs)

Uçan adalar arasında geçen, hikâyeli bir uçuş oyunu. Flutter + Flame ile
yazıldı; iOS, Android ve web'de çalışır. Tüm görseller kodla çizilir, dışarıdan
görsel, ses ya da veri yüklenmez; oyun hiçbir sunucuyla konuşmaz.

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

## Bilinen eksikler

- Ses ve müzik yok.
- Gerçek telefonlarda denenmedi; tarayıcıda (Chromium) ve testlerde denendi.
- Uygulama simgesi Flutter'ın varsayılanı; paket kimliği
  `com.bulutkorsanlari.bulut_korsanlari` yer tutucudur.
