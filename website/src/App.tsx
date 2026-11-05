import { useEffect } from 'react'
import changelogMd from '../../CHANGELOG.md?raw'
import { parseChangelog } from './changelog'

const REPO = 'https://github.com/mirhatuguzlu/e-medrese'
const APK = `${REPO}/releases/latest/download/e-medrese.apk`
const releases = parseChangelog(changelogMd)
const latest = releases[0]
const YEAR = new Date().getFullYear()

const features = [
  {
    icon: '🕌',
    title: 'Medresen, tek yerde',
    text: 'Kodla katıl ya da kendi medreseni kur. Duyurular, paylaşımlar, yorumlar ve üyeler bir arada; önemli olan anında bildirim olarak düşer.',
  },
  {
    icon: '📿',
    title: 'Haftalık görev takibi',
    text: 'Namaz, okuma, Cevşen… Her gün işaretle, hafta sonunda yıldızın parlayarak açılsın. Puanlar toplanır, sıralama kızışır.',
  },
  {
    icon: '🎁',
    title: 'Ödüller ve hedefler',
    text: 'Hoca ödül koyar, öğrenci hedef seçer. Uygulama kalan günlere göre her gün ne kadar yapman gerektiğini söyler.',
  },
  {
    icon: '🎓',
    title: 'Online Medrese',
    text: 'Bölüm bölüm video kurslar. İlk izleyişte ileri sarılmaz; not al, tekrar sorularını çöz, ders altında hocana sor.',
  },
  {
    icon: '📜',
    title: 'Hoca onaylı icazet',
    text: 'Hocan kursu medresene verir, ilerlemeni görür. Kursu bitir, icazet iste; onaylanan belgede hoca, medrese ve belge numarası yazar.',
  },
  {
    icon: '🔒',
    title: 'Verin senin',
    text: 'KVKK uyumlu: her veri için ayrı açık rıza, rızanı geri alınca verin silinir. Reklam yok, takip yok.',
  },
]

const steps = [
  ['İndir', 'APK’yı indir, kur. Yeni sürüm çıkınca uygulama kendisi haber verir.'],
  ['Google ile gir', 'Şifre yok, kayıt formu yok. Tek dokunuş.'],
  ['Medresene katıl', 'Hocandan aldığın kodu gir ya da medreseni kur, öğrencilerini davet et.'],
]

function useReveal() {
  useEffect(() => {
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => e.isIntersecting && e.target.classList.add('in')),
      { threshold: 0.15 },
    )
    document.querySelectorAll('.reveal').forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])
}

function Phone() {
  return (
    <div className="phone" aria-hidden="true">
      <div className="screen">
        <div className="bar">Bu hafta</div>
        <div className="star">★</div>
        <div className="star-label">Haftalık puanın hazır!</div>
        {[
          ['Namaz', '5 / 5 vakit', 100],
          ['Kur’an', 'Her gün 20 sayfa', 70],
          ['Cevşen', '2 / 3 hatim', 66],
        ].map(([name, sub, pct]) => (
          <div className="task" key={name}>
            <div>
              <b>{name}</b>
              <small>{sub}</small>
            </div>
            <div className="meter">
              <span style={{ width: `${pct}%` }} />
            </div>
          </div>
        ))}
        <div className="course">
          <span>▶</span>
          <div>
            <b>Siyer · 4. ders</b>
            <small>Kaldığın yerden devam et</small>
          </div>
        </div>
      </div>
    </div>
  )
}

export default function App() {
  useReveal()
  return (
    <>
      <header className="hero">
        <nav>
          <a className="brand" href="#">
            <img src={`${import.meta.env.BASE_URL}icon.png`} alt="" width="32" height="32" />
            e-Medrese
          </a>
          <a className="nav-link" href="#yenilikler">Yenilikler</a>
        </nav>
        <div className="hero-body">
          <div className="hero-text">
            <span className="pill">v{latest.version} yayında</span>
            <h1>
              Medresen <em>cebinde.</em>
            </h1>
            <p className="lead">
              Duyurular, haftalık görevler, ödüller ve hocalı online kurslar. Talebe ile hoca arasındaki her şey, tek
              uygulamada.
            </p>
            <div className="cta">
              <a className="btn primary" href={APK}>
                Android için indir
              </a>
              <a className="btn ghost" href="#ozellikler">
                Neler var?
              </a>
            </div>
            <small className="muted">Ücretsiz · Reklamsız · Google ile giriş</small>
          </div>
          <Phone />
        </div>
      </header>

      <main>
        <section id="ozellikler">
          <h2 className="reveal">Bir medresenin ihtiyacı olan her şey</h2>
          <div className="grid">
            {features.map((f) => (
              <article className="card reveal" key={f.title}>
                <div className="icon">{f.icon}</div>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section className="steps-section">
          <h2 className="reveal">Üç adımda başla</h2>
          <ol className="steps">
            {steps.map(([t, d], i) => (
              <li className="reveal" key={t}>
                <span className="num">{i + 1}</span>
                <h3>{t}</h3>
                <p>{d}</p>
              </li>
            ))}
          </ol>
        </section>

        <section id="yenilikler">
          <h2 className="reveal">Yenilikler</h2>
          <p className="muted center reveal">Uygulama sürekli gelişiyor. Son sürümlerde gelenler:</p>
          <div className="timeline">
            {releases.slice(0, 4).map((r) => (
              <article className="release reveal" key={r.version}>
                <header>
                  <b>v{r.version}</b>
                  {r.date && <time>{r.date}</time>}
                </header>
                <ul>
                  {r.items.map((it) => (
                    <li key={it}>{it}</li>
                  ))}
                </ul>
              </article>
            ))}
          </div>
          <p className="center">
            <a href={`${REPO}/blob/main/CHANGELOG.md`}>Bütün sürüm geçmişi →</a>
          </p>
        </section>

        <section className="final reveal">
          <h2>Medreseni bugün taşı.</h2>
          <a className="btn primary" href={APK}>
            APK’yı indir (v{latest.version})
          </a>
        </section>
      </main>

      <footer>
        <span>© {YEAR} e-Medrese · Mirhat Muhammed Uğuzlu</span>
        <a href="mailto:dev.mirhat@gmail.com">dev.mirhat@gmail.com</a>
        <span>Bu site çerez kullanmaz, veri toplamaz.</span>
      </footer>
    </>
  )
}
