# Müzik promptları

Bulut Korsanları için 9 parça: 6 döngü (ekranda sürekli çalar) ve 3 kısa
nida (görev sonu, epilog). Promptlar İngilizce, çünkü müzik üreticileri
(Gemini, Suno, Udio vb.) İngilizceyi daha iyi anlar. Hepsi sözsüz
(enstrümantal) olmalı.

**Ortak ses kimliği:** orkestral macera + Anadolu çalgıları (bağlama,
darbuka, davul, ney, zurna) + akordeon. Bütün parçalarda aynı çalgı
ailesi geçtiği için oyun tek bir dünyaya ait gibi duyulur. Promptlarda
sanatçı, film ya da başka oyun adı geçmez; hem üreticiler bunları reddeder
hem de sonuç taklit gibi durur.

## Döngüler

| # | Dosya | Nerede çalar | Tempo | Süre |
| --- | --- | --- | --- | --- |
| 1 | `menu` | Ana menü, yeni pilot | 140 BPM | 1:30–2:00 |
| 2 | `logbook` | Seyir defteri, brifing, değerlendirme, kayıtlar | 116 BPM | 1:30 |
| 3 | `dogfight` | İt dalaşı (görev 1, 3, 5) | 168 BPM | 2:00 |
| 4 | `raid` | Alçak baskın (görev 2, 6) | 150 BPM | 1:30 |
| 5 | `bombing` | Bombardıman (görev 4, 7) | 128 BPM | 1:30 |
| 6 | `finale` | Kaptan Kuzgun ve Fırtına Ana (görev 8, 9) | 160 BPM | 2:00 |

### 1. menu: Ana tema

```
Energetic orchestral adventure theme for a sky pirate game, soaring heroic brass melody, fast string ostinato, bright bağlama riffs, darbuka and snare rolls, accordion countermelody, sense of flying between floating islands, playful and bold, major key, 140 BPM, instrumental, video game main theme, seamless loop
```

### 2. logbook: Seyir defteri / brifing

```
Upbeat adventure briefing music, bouncy pizzicato strings, warm accordion melody, light bağlama plucks, frame drum groove, ticking clock percussion, curious and determined mood, preparing for a mission, D major, 116 BPM, instrumental, game menu loop, seamless loop
```

### 3. dogfight: İt dalaşı

```
High-energy aerial combat music, driving staccato strings, pounding davul and taiko drums, heroic brass stabs, fast bağlama runs, pulsing electric bass, urgent minor key, relentless forward momentum, propeller planes chasing through clouds, 168 BPM, instrumental, video game battle loop, seamless loop
```

### 4. raid: Alçak baskın

```
Swashbuckling fast chase music, galloping 6/8 rhythm, darbuka and snare drum, plucked bağlama and mandolin lead, punchy brass hits, mischievous pirate energy, low-altitude raid over an island harbour, minor key with bright accents, 150 BPM, instrumental, video game action loop, seamless loop
```

### 5. bombing: Bombardıman

```
Tense propulsive mission music, steady marching pulse, low string ostinato, timpani and ticking percussion, breathy ney flute over wind ambience, brass rising toward a climax, suspense that keeps moving forward, bombing run above the clouds, minor key, 128 BPM, instrumental, video game loop, seamless loop
```

### 6. finale: Son savaş

```
Epic final battle music, full orchestra with wordless choir, thunderous davul and taiko, aggressive zurna lead, heavy brass, storm and thunder atmosphere, dark minor key that turns heroic in the second half, maximum intensity, 160 BPM, instrumental, video game boss theme, seamless loop
```

## Kısa nidalar

Üreticiler genelde 30 saniyeden kısa parça vermez; gelen parçanın ilk
saniyeleri kesilerek kullanılır.

| # | Dosya | Nerede çalar | Süre |
| --- | --- | --- | --- |
| 7 | `victory` | Görev başarılı | 5–8 sn |
| 8 | `defeat` | Hedef tutturulamadı / düşürüldü | 5–8 sn |
| 9 | `ending` | Sefer sonu (epilog), döngü olabilir | 1:00–1:30 |

### 7. victory: Zafer

```
Short triumphant victory fanfare, bright brass and strings, quick bağlama flourish, cymbal swell, joyful major key, ends on a clean final chord, under 8 seconds, instrumental, video game mission complete jingle
```

### 8. defeat: Yenilgi

```
Short somber defeat sting, falling string phrase, soft ney flute, single low drum hit, minor key, ends quietly, under 8 seconds, instrumental, video game mission failed jingle
```

### 9. ending: Bayram / epilog

```
Joyful celebration finale, festival on a floating island town, festive davul and zurna rhythm, hand claps, bağlama and accordion melody, triumphant orchestral brass, uplifting major key, 132 BPM, instrumental, video game ending theme
```

## Üretirken

- Her prompt için 2–4 deneme üret, en iyisini seç.
- **Araç: Gemini uygulamasındaki müzik üretimi (Lyria).** Her prompta
  "no vocals" ekle ve şarkı sözü yerine enstrümantal seç. Ücretsiz planda
  parçalar 30 saniyeyle sınırlı olabilir; döngüler için 1–3 dakikalık
  parça veren bir plan daha iyi sonuç verir.
- **Hak durumu:** Google Hizmet Şartları (30 Temmuz 2026): "Google won't
  claim ownership over that content." Aynı şartlar yapay zekâ içeriğini
  insan yapımı gibi göstermeyi yasaklar; bu yüzden künyede müziğin
  Gemini ile üretildiği yazılır. Parçalarda duyulmayan SynthID filigranı
  vardır.
- Hangi araç, hangi plan ve hangi tarihte üretildiği
  `assets/audio/MUSIC_SOURCE.txt` dosyasına yazılacak.
- WAV ya da yüksek kaliteli MP3 olarak indir. Döngü noktası, ses seviyesi
  eşitleme ve oyuna uygun biçime çevirme (OGG/M4A) oyuna eklenirken yapılır.
