# Ses efekti promptları

Oyunda şu an `tool/generate_sfx.py` ile kodla sentezlenmiş 9 efekt var.
Bu promptlarla bir yapay zekâ ses efekti üreticisinde daha gerçekçi
sürümler üretilirse, aynı adlarla yerlerine konur; oyun kodu değişmez.

- Promptlar İngilizce. Hepsinde müzik ve insan sesi olmamalı.
- **Döngüler** (`gun`, `engine`): baştan sona aynı yoğunlukta, başlangıcı
  ve bitişi olmayan ses. Dikişsiz dönmesini ben ayarlarım.
- **Tek seferlikler:** ses hemen başlamalı; baştaki sessizlik gecikme
  demektir.
- Her prompttan 3–4 deneme üret. WAV ya da yüksek kaliteli MP3 indir,
  dosyaya bu adı ver.
- Hazırlığı ben yaparım: sessizlik kırpma, ses seviyesi eşitleme, döngü
  dikişi, 22,05 kHz mono WAV'a çevirme.
- **Lisans:** Kullandığın aracın ticari kullanım şartlarına bak; ücretsiz
  planlar çoğu zaman ticari kullanıma izin vermez ya da atıf ister. Araç,
  plan ve tarih künyeye yazılacak.

| Dosya | Nerede | Süre |
| --- | --- | --- |
| `gun` | Ateş tuşu basılıyken (döngü) | 2–4 sn |
| `engine` | Görev boyunca, hıza göre perdesi değişir (döngü) | 4–6 sn |
| `explosion` | Düşen uçak, yok edilen hedef, bomba | ~2 sn |
| `hit` | Mermimiz isabet edince | < 0,5 sn |
| `damage` | Bizim uçak vurulunca | < 1 sn |
| `flak` | Uçaksavar patlaması | ~1 sn |
| `bomb` | Bomba bırakılınca, düşerken ıslık | ~1,8 sn |
| `jam` | Silah ısınıp tutukluk yapınca | < 0,5 sn |
| `warning` | Bulut denizine fazla yaklaşınca | ~0,5 sn |

### gun (döngü)

```
Vintage 1920s biplane twin machine guns firing continuously, rapid steady mechanical rattle of about ten rounds per second, sharp gunshot cracks with the metallic clatter of the gun action, heard from the open cockpit, dry with no echo. Seamless loop with constant intensity, no start and no end. No music, no voices.
```

### engine (döngü)

```
Old radial piston engine of a 1920s propeller biplane at steady cruising power, heard from inside the open cockpit: a deep throbbing drone with the rhythmic whoosh of the propeller and wind rushing past. Constant pitch and volume, seamless loop with no start and no stop. No music, no voices.
```

### explosion

```
Mid-air explosion of a wooden biplane: a sharp initial blast, a deep booming fireball, then crackling flames and splintering wood debris scattering, heard from a short distance in open sky. About two seconds, the sound begins instantly and fades naturally at the end. No music, no voices.
```

### hit

```
A single bullet striking a wood-and-canvas aircraft: a short, sharp thwack with a small metallic ping. Very short, under half a second, starts instantly, no reverb. No music, no voices.
```

### damage

```
Bullets ripping into the pilot's own biplane, heard from inside the cockpit: a heavy thud, wood splintering, canvas tearing and a quick metallic rattle. Under one second, starts instantly. No music, no voices.
```

### flak

```
An anti-aircraft flak shell bursting in the sky nearby, heard from an aircraft cockpit: a muffled heavy whump with a short pressure crack and a faint hiss of shrapnel. About one second, starts instantly. No music, no voices.
```

### bomb

```
An aerial bomb released from a biplane: a short mechanical clunk of the bomb rack, then the falling whistle of the bomb descending in pitch for about one and a half seconds, ending abruptly just before impact. No explosion, no music, no voices.
```

### jam

```
A machine gun jamming: two harsh metallic clanks of a stuck gun bolt followed by a dry mechanical click. Under half a second, starts instantly, no gunfire. No music, no voices.
```

### warning

```
A vintage aircraft cockpit warning buzzer: a short two-tone electric alarm, slightly rough and mechanical, about half a second long. No music, no voices.
```
