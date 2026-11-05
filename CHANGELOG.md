# Changelog

Sürüm biçimi `x.y.z+build`: `z` hata düzeltme, `y` yeni özellik, `x` geriye uyumsuz büyük değişiklik.
## 2.11.1+34 — 2026-11-05
- Profil fotoğrafları her yerde: duyurular, paylaşımlar ve yorumlar, ders tartışmaları, sıralama, görev takibi, kurs ilerlemesi, icazet ve ödül istekleri.

## 2.11.0+33 — 2026-11-05
- Profil yenilendi: adını değiştirebilir, galeriden profil fotoğrafı ekleyip kaldırabilirsin. Fotoğrafın medresendeki üyelere, üye listesinde ve üye sayfasında görünür; hesabını silince o da silinir. Profilde e-postan, medreselerin ve rolün, üyelik tarihin de yazar.
- Ayarlar: Profil sayfasının sağ üstündeki düğmeyle açılır. Tema (telefona uy, açık, koyu), yazı boyutu, bildirim izni, önbelleği temizleme ve Uygulama hakkında (sürüm, güncelleme denetimi, web sitesi) var. Aydınlatma metni, rızalar, künye ve hesap silme de Ayarlar'a taşındı.
- Aydınlatma metni profil fotoğrafıyla güncellendi.

## 2.10.3+32 — 2026-11-05
- Ana ekranda uygulamanın adı "e_medrese" yerine "e-Medrese" yazar.

## 2.10.2+31 — 2026-11-05
- Yeni uygulama simgesi: yeşil zemin üzerinde altın mihrap, yıldız ve açık kitap. Bildirimlerde de aynı şeklin tek renkli hali görünür.

## 2.10.1+30 — 2026-11-05
- 2.9.0'da telefona kaydedilen kurslar, Online Medrese rızası (sürüm 4) verilince hesaba taşınır ve telefondan silinir; hesap silinince telefonda kalanlar da silinir.
- Aydınlatma metninin güncelleme tarihi düzeltildi.

## 2.10.0+29 — 2026-11-05
- Kaydedilen kurslar artık hesapta saklanır, bütün telefonlarda Kurslarım'da görünür. Kaydetmek Online Medrese rızası ister; rıza metni (sürüm 4) ve aydınlatma metni güncellendi, rıza verenlerden yeniden onay istenir. Rıza geri alınınca kayıtlar da silinir.
- Güncelleme artık telefonun işlemcisine uygun, yaklaşık üçte bir boyutlu APK'yı indirir.

## 2.9.1+28 — 2026-11-05
- Güncelleme ekranı yenilendi: düz beyaz sayfa yerine renkli zemin ve kart; uygulamanın bozulduğu izlenimi vermiyor.

## 2.9.0+27 — 2026-11-09
- Kurs kaydetme: kurs sayfasındaki yer imiyle kaydedilen kurslar "Kurslarım"da "Kaydettiklerin" altında. Kayıtlar yalnız telefonda tutulur; hesap silinince telefondan da silinir.
- Ders kaynakları: yöneticiler derse PDF ya da web sayfası linki ekler (yalnız https); öğrenci ders sayfasındaki "Ders kaynakları"ndan açar.
- Ders tartışması bildirimine (uygulama içi ya da telefon bildirimi) dokununca doğrudan o dersin tartışması açılır.
- Aydınlatma metni güncellendi (kaynak linkleri, telefonda tutulan kayıtlar).

## 2.8.0+26 — 2026-11-08
- Tekrar soruları: yöneticiler derslere çoktan seçmeli soru ekler (2–5 şık, açıklama). Öğrenci dersi bitirince çözer; yanlışta doğrusu ve açıklaması görünür. İlk cevap kaydedilir, yeniden çözmek serbest. Hocalar verdikleri kursta doğru sayısını görür.
- Medrese içi ders tartışması: hocanın verdiği kursun derslerinde yalnız medrese üyelerinin gördüğü soru-cevap; yazı videonun o anına bağlanabilir, ana dokununca video oraya gider. Hocanın yazısı "Hoca" rozetli; hocalar kursun bütün tartışmalarını tek sayfada görür. Şikayet ve silme var; bildirim gider.
- Hoca onaylı icazet: verilen kursu bitiren öğrenci icazet ister, hoca notuyla onaylar ya da geri çevirir (geri çevrilen yeniden istenir). İcazet belgesinde onaylayan hoca, medrese ve belge numarası yazar. Hoca onayı olmayan kurslarda "Tamamlama belgesi" verilir.
- Görev puanı: hocanın verdiği kurslarda bir haftada bitirilen her ders 5 puan (en fazla 10 ders) "Online kurs" görevi olarak haftalık puana ve sıralamaya eklenir. Görev kartı yalnız kurs verilen medresede görünür.
- İsimsiz kurs değerlendirmesi: en az bir dersini bitiren 1–5 yıldız ve yorum yazar; adlar gösterilmez. Puan katalogda ve kurs sayfasında görünür; değerlendirmeler şikayet edilebilir.
- Kurs seviyesi (başlangıç/orta/ileri) ve "Bu kursta öğreneceklerin" listesi.
- Kurs arama (başlık, hoca, konu, ders adları; seviyeye göre) ve "Kurslarım" sayfası (devam edenler, bitenler, toplam izleme).
- Sorusu olmayan ders bitince sonraki ders 5 sn sonra kendiliğinden açılır ("Burada kal" ile durdurulur); sorusu varsa "Soruları çöz" çıkar.
- Düzeltme: kategori ve seviye başlıklarında Türkçe büyük harf (SİYER, HADİS).
- Online Medrese rıza metni (sürüm 3) ve aydınlatma metni yeni verilerle güncellendi; önceki rızayı verenlere bir kez yeniden sorulur. Rıza geri alınınca soru cevapları, değerlendirmeler, icazet istekleri silinir, haftalık puanlardan kurs payı düşülür.

## 2.7.0+25 — 2026-11-07
- Düzeltme: ders ilerlemesi 1. dakikada takılıyor, ders tamamlanmıyordu (sunucu doğrulaması kaydı her seferinde yeni sayıyordu). Kalınan yer ve tamamlanma artık doğru kaydediliyor; sunucu kabul etmezse uygulama yeniden deniyor.
- Tam ekranda durum ve gezinme çubukları gizleniyor, ekran yatay dönüyor.
- Hız: seçilen hız ekranda görünüyor, YouTube hızı kendiliğinden 1x'e döndürürse yeniden uygulanıyor.
- Altyazı kapalı açılıyor; oynatıcıdaki CC düğmesiyle açılıp kapanıyor.
- Hocanın verdiği kurslar: hocalar medrese sayfasındaki "Online kurslar"dan medreseye kurs verir (isteğe bağlı son gün), öğrencilere bildirim gider. Kurs öğrencinin akışında "Hocan verdi" etiketiyle en üstte çıkar. Hocalar rıza veren öğrencilerin o kurstaki ilerlemesini görür.
- Ders notları: izlerken "Not al" ile videonun o anına not; "Notlarım"da nota dokununca video o ana gider.
- İcazet: bütün dersleri biten kursun sayfasından icazet görüntülenir.
- Online Medrese rıza metni yenilendi (hocalarla ilerleme paylaşımı, notlar); önceki rızayı verenlere bir kez yeniden sorulur. Aydınlatma metni güncellendi.

## 2.6.0+24 — 2026-11-05
- Kurs yönetimi: uygulama yöneticileri Online Medrese sayfasındaki düğmeyle kurs açar, bilgisini düzenler, yayına alır ya da siler. Ders, YouTube linki yapıştırılarak eklenir (başlık YouTube'dan gelir); dersler sürüklenerek sıralanır.
- Video oynarken ekran kararmıyor; duraklayınca YouTube önerileri görünmüyor.
- Sunucu ders ilerlemesini doğruluyor: izlenen süre gerçek zamandan hızlı artamaz, ders ancak %90'ı izlenince tamamlanır.

## 2.5.0+23 — 2026-11-05
- Online Medrese açıldı: YouTube derslerinden oluşan kurslar. Akışta "Kaldığın yerden devam et" kartı, kategoriler ve ilerlemeli kurs kartları; kurs sayfasında bölümlü ders listesi ve sıradaki dersi açan düğme.
- Ders oynatıcı kendi düğmeleriyle: oynat/duraklat, 10 sn geri, hız (0.75x–2x), tam ekran, iki kez dokunarak sarma. İlk izleyişte izlenmemiş kısma sarılamaz; geri sarmak serbest. Dersin %90'ı izlenince ders tamamlanır, sonra serbestçe sarılır. Kalınan yer kaydedilir.
- Ders ilerlemesi için ayrı açık rıza (Profil > Online Medrese rızası); geri alınınca ilerleme silinir. Aydınlatma metnine ders ilerlemesi ve YouTube eklendi.

## 2.4.0+22 — 2026-11-04
- Zorunlu güncelleme: GitHub'da yeni bir sürüm çıktıysa uygulama "Bu sürüm artık mevcut değil" sayfasını gösteriyor ve güncellenene kadar kullanılamıyor. "Uygulamayı güncelle" düğmesi son APK'yı indiriyor. Kontrol her açılışta ve uygulama öne her geldiğinde yapılıyor; internet yoksa uygulama kilitlenmiyor.
- Aydınlatma metnine GitHub sürüm kontrolü eklendi.


## 2.3.3+21 — 2026-11-04
- Hedef kartı kapalı başlar, altındaki görev kartları ekranda kalır. Dokununca hedefin görev satırları açılır.
- Sağ üstteki "DEBUG" yazısı kalktı.

## 2.3.2+20 — 2026-11-04
- Ana sayfadaki hedef kartında her görev ayrı satır: satırda her gün ne yapılacağı kısaca yazar (ör. "Her gün 20 sayfa"), dokununca açıklaması aşağı açılır.

## 2.3.1+19 — 2026-11-04
- Hedef seçerken takvimde en erken gün, bütün görevler tam yapılsa ödüle ulaşılan gündür; daha erken günler seçilemez. Süren haftada geçen günler ve yapılanlar hesaba katılır, uyum puanı katılmaz.

## 2.3.0+18 — 2026-11-04
- Hoca bekleyen ödül isteğini "Reddet" ile, nedenini yazarak reddedebilir. Öğrenciye neden bildirim olarak gider ve Ödüller sayfasında yazar; ayrılan puan öğrenciye döner, ödülü yeniden isteyebilir.

## 2.2.0+17 — 2026-11-04
- Öğrenci ödülün puanına ulaşınca "Ödülü iste"ye basar; hocalara bildirim gider. Hoca, Ödül istekleri sayfasında yalnız istenmiş ödülü "Teslim edildi" işaretleyebilir (bildirim gitmese de istek görünür).
- İstenen ödülün puanı birikmiş puandan ayrılır, teslim edilince düşülmüş olur; aynı ödül teslim edilmeden yeniden istenemez. Teslim edilen ödül hedeften kalkar.
- Hoca ödül ekleyince öğrencilere bildirim gider.
- Ana sayfa önerisi bu hafta yapılanı düşer: her görevde bu hafta kalan miktar ve kalan günlere göre günlük miktar yazar.

## 2.1.0+16 — 2026-11-04
- Ödüller sayfası: hoca birikmiş puan eşikli ödüller ekler ve siler; öğrenci birikmiş puanını ve ödüllere kalan puanı görür.
- Öğrenci bir ödülü bitiş günüyle hedef seçer. Ana sayfada öneri çıkar: namaz her gün 5 vakit tam, kalan puan diğer görevlere en yüksek puanlarına oranla bölünür (günde ya da haftada en az). Uyum puanı hesaba katılmaz, bu öğrenciye yazılır.
- Görev takibi rızası geri alınınca hedef de silinir.

## 2.0.0+15 — 2026-11-02
- Hukuki uyum (KVKK, 5651, 5846). Giriş ekranında aydınlatma metni var; okunduğu onaylanmadan giriş yapılamıyor. Profil'de aydınlatma metni, görev takibi rızası, künye ve iletişim, hesap silme sayfaları açıldı.
- Görev takibi (namaz, okuma) artık açık rıza istiyor. Rıza verilmeden öğrenci de hoca da girdi yazamıyor. Rıza geri alınınca görev girdileri ve haftalık puanlar siliniyor. Eski sürümler rıza veremediği için görev işaretleyemez, bu yüzden büyük sürüm atlandı.
- Paylaşım ve yorumlar şikayet edilebiliyor (telif hakkı ihlali dahil). Yorumu yazan kişi, kurucu ve hocalar yorumu silebiliyor.
- Kurucu, başka bir üyeyi kurucu yapabiliyor. Başka üyesi olan bir medresenin kurucusu, hesabını silmeden önce kuruculuğu devretmek zorunda.
- Telefon bildirimlerine duyuru ve yorum metni yazılmıyor; genel bir metin gidiyor.
- İçerik oluşturma kayıtları (zaman, IP) 2 yıl tutuluyor.
- Profil sayfasının son satırı alttaki menünün altında kalmıyor.

## 1.11.1+14 — 2026-11-01
- Medreselerim ve medrese sayfasındaki bölümler (Duyurular, Paylaşımlar, …) kart oldu: büyük simge, altında yazı; telefonda yan yana 2, geniş ekranda 3–4 kart.

## 1.11.0+13 — 2026-11-01
- Ana sayfa artık Görev takibi: menünün ortasında büyük yuvarlak düğme, uygulama bununla açılır. Öğrenci görev kartlarını, hoca görev takibini görür; görevler başlamadıysa öğrenciye yazılır.
- Medreselerim'de tek medrese varsa doğrudan o medresenin sayfası açılır.
- Menüde "Online Medrese" yerine "Online" yazar.

## 1.10.0+12 — 2026-11-01
- Ekranın altında havada duran menü: Medreselerim, Online Medrese (çok yakında), Bildirimler (okunmamış sayısıyla) ve Profil. "Koda katıl" ve "Medrese kur" üst çubuğa taşındı.

## 1.9.0+11 — 2026-11-01
- Bütün bildirimler tıklanabilir: görev bildirimleri ana ekrandaki görevlere, duyuru duyurulara, "Yıldızların hazır" yıldız sayfasına (gün geçtiyse puan geçmişine), yorum paylaşıma götürür. Telefondaki bildirime dokununca da doğrudan ilgili sayfa açılır.

## 1.8.0+10 — 2026-11-01
- Paylaşımına başkası yorum yazınca bildirim gelir; Bildirimler sayfasında dokununca paylaşım ve yorumları açılır.

## 1.7.0+9 — 2026-11-01
- Geçmiş günler kilitli: öğrenci yalnızca bugünü, gece 04:00'e kadar dünü de işaretleyebilir; geçen günler salt okunur görünür. Haftalık Cevşen dönem boyunca açık kalır.
- Hoca ve kurucu, Görev takibinde öğrencinin yanındaki takvim simgesiyle süren dönemin geçmiş günlerini düzeltebilir.

## 1.6.1+8 — 2026-11-01
- Bildirimler telefona düşmüyordu: sunucu çağrısındaki anahtar temizleniyor. Uygulama açıkken de bildirim sesli olarak görünür; kapalıyken gelenler aynı sesli kanala düşer.

## 1.6.0+7 — 2026-11-01
- Bildirimler: görev başlatma, durdurma, devam ve bitişte öğrencilere; yeni duyuruda medresedeki herkese; dönem bitince "Yıldızların hazır"; 21:00'de o gün işaretleme yapmayan öğrenciye hatırlatma. Ana ekrandaki zil okunmamış sayısını gösterir ve Bildirimler sayfasını açar.

## 1.5.0+6 — 2026-11-01
- Görev takibinde hoca ve kurucu için iki tuş: Durdur (öğrenciler işaretleyemez, Devam et ile sürer) ve Bitir (süren dönem o ana kadarki girdilerle puanlanır, program kapanır).

## 1.4.0+5 — 2026-11-01
- Haftalık sandık yerine yıldız: dokundukça büyüyüp parlar, ışık saçarak açılır. Puanlar tek tek sayılır, yıldız olup toplama düşer; kart "Haftalık puanın hazır!" yazar.

## 1.3.0+4 — 2026-10-31
- Giriş yalnızca Google hesabıyla; e-posta/şifre ile giriş ve kayıt kaldırıldı.

## 1.2.0+3 — 2026-10-31
- Google ile giriş: giriş ekranında "Google ile devam et"; hesap yoksa ilk girişte açılır.

## 1.1.0+2 — 2026-10-28
- Uyum: hoca her dönem öğrenciye en fazla 25 puan ve not verir; öğrenci dönem bitince sandıkta görür. Öğrenci kartı görür ama işaretleyemez.
- Cevşen okuma: haftada kaç kez bitirildiği işaretlenir (1 kez = 25 puan, en fazla 3 kez).

## 1.0.0+1
- İlk sürüm: topluluk (medrese, üyeler, duyurular, paylaşımlar), haftalık görevler, sandık, puan geçmişi ve sıralama.
