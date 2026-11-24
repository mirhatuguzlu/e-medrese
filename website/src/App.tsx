import { useEffect, type CSSProperties } from 'react'
import changelogMd from '../../CHANGELOG.md?raw'
import { parseChangelog } from './changelog'

const REPO = 'https://github.com/mirhatuguzlu/e-medrese'
const APK = `${REPO}/releases/latest/download/e-medrese.apk`
const HERO_VIDEO =
  'https://d2ol7oe51mr4n9.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/6b0bd33e-2a03-471d-b61d-3d49f25ca16f.mp4'
const releases = parseChangelog(changelogMd)
const latest = releases[0]
const YEAR = new Date().getFullYear()
/** Staggered entrance delay for `.rise` (seconds). */
const delay = (s: number) => ({ '--d': `${s}s` }) as CSSProperties

const features = [
  {
    icon: 'M4 21V11l8-6 8 6v10 M9 21v-5a3 3 0 0 1 6 0v5 M12 2v3',
    title: 'Medresen, tek yerde',
    text: 'Kodla katıl ya da kendi medreseni kur. Duyurular, paylaşımlar, yorumlar ve üyeler bir arada; önemli olan anında bildirim olarak düşer.',
  },
  {
    icon: 'M5 4h14v16H5z M9 9l2 2 4-4 M9 15h6',
    title: 'Haftalık görev takibi',
    text: 'Namaz, okuma, Cevşen… Her gün işaretle, hafta sonunda yıldızın parlayarak açılsın. Puanlar toplanır, sıralama kızışır.',
  },
  {
    icon: 'M4 10h16v10H4z M3 7h18v3H3z M12 7v13 M12 7c-2-4-6-3-5 0 M12 7c2-4 6-3 5 0',
    title: 'Ödüller ve hedefler',
    text: 'Hoca ödül koyar, öğrenci hedef seçer. Uygulama kalan günlere göre her gün ne kadar yapman gerektiğini söyler.',
  },
  {
    icon: 'M5 4h14v12H5z M10 8l4 2-4 2z M8 20h8',
    title: 'Online Medrese',
    text: 'Bölüm bölüm video kurslar. İlk izleyişte ileri sarılmaz; not al, tekrar sorularını çöz, ders altında hocana sor.',
  },
  {
    icon: 'M7 3h10v18l-5-3-5 3z M10 8h4 M10 12h4',
    title: 'Hoca onaylı icazet',
    text: 'Hocan kursu medresene verir, ilerlemeni görür. Kursu bitir, icazet iste; onaylanan belgede hoca, medrese ve belge numarası yazar.',
  },
  {
    icon: 'M6 11h12v10H6z M8 11V8a4 4 0 0 1 8 0v3 M12 15v2',
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

export default function App() {
  useReveal()
  return (
    <>
      <header className="hero">
        {/* MotionSites cinematic video hero; free loop from motionsites.ai/backgrounds ("Golden Stairwell"). */}
        <video className="hero-video" src={HERO_VIDEO} autoPlay muted loop playsInline preload="auto" aria-hidden="true" />
        <div className="hero-scrim" aria-hidden="true" />
        <nav className="glass-nav rise" style={delay(0.05)}>
          <a className="brand" href="#">
            <img src={`${import.meta.env.BASE_URL}icon.png`} alt="" width="30" height="30" />
            e-Medrese
          </a>
          <div className="nav-links">
            <a href="#ozellikler">Özellikler</a>
            <a href="#yenilikler">Yenilikler</a>
            <a className="nav-cta" href={APK}>İndir</a>
          </div>
        </nav>
        <div className="hero-text">
          <span className="pill rise" style={delay(0.2)}>
            v{latest.version} yayında
          </span>
          <h1>
            <span className="rise" style={delay(0.35)}>Medresen</span>{' '}
            <em className="rise" style={delay(0.5)}>cebinde.</em>
          </h1>
          <p className="lead rise" style={delay(0.7)}>
            Duyurular, haftalık görevler, ödüller ve hocalı online kurslar. Talebe ile hoca arasındaki her şey, tek
            uygulamada.
          </p>
          <div className="cta rise" style={delay(0.85)}>
            <a className="btn primary" href={APK}>
              Android için indir
            </a>
            <a className="btn ghost" href="#ozellikler">
              Neler var?
            </a>
          </div>
        </div>
        <ul className="hero-facts rise" style={delay(1.05)}>
          <li>Ücretsiz</li>
          <li>Reklamsız</li>
          <li>Google ile tek dokunuşla giriş</li>
          <li>KVKK uyumlu</li>
        </ul>
      </header>

      <main>
        <section id="ozellikler">
          <h2 className="reveal">Bir medresenin ihtiyacı olan her şey</h2>
          <div className="grid">
            {features.map((f) => (
              <article className="card reveal" key={f.title}>
                <div className="icon">
                  <svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true">
                    <path d={f.icon} fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </div>
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
