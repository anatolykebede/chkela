import { COPY, FEATURES } from '../content'
import { ClaimGiftButton } from '../components/ClaimGiftButton'
import { PhoneMock } from '../components/PhoneMock'
import { SchoolMarquee } from '../components/SchoolMarquee'
import { StoreButtons } from '../components/StoreButtons'
import './HomePage.css'

export function HomePage() {
  return (
    <div className="home">
      <section className="hero">
        <div className="hero-atmosphere" aria-hidden>
          <div className="hero-orb hero-orb--a" />
          <div className="hero-orb hero-orb--b" />
          <div className="hero-orb hero-orb--c" />
          <svg className="hero-constellation" viewBox="0 0 800 600" fill="none">
            <g stroke="rgba(184,174,255,0.22)" strokeWidth="1">
              <path d="M120 140 L240 90 L360 160 L480 70 L620 130 L700 80" />
              <path d="M160 320 L280 260 L400 340 L520 250 L640 310" />
              <path d="M200 480 L340 420 L460 500 L600 430" />
              <path d="M240 90 L280 260 L340 420" />
              <path d="M480 70 L400 340 L460 500" />
            </g>
            <g fill="rgba(184,174,255,0.55)">
              <circle cx="120" cy="140" r="2.5" />
              <circle cx="240" cy="90" r="3.5" className="star-pulse" />
              <circle cx="360" cy="160" r="2" />
              <circle cx="480" cy="70" r="3" />
              <circle cx="620" cy="130" r="2.5" />
              <circle cx="700" cy="80" r="2" />
              <circle cx="280" cy="260" r="3" className="star-pulse" />
              <circle cx="400" cy="340" r="2.5" />
              <circle cx="520" cy="250" r="2" />
              <circle cx="340" cy="420" r="3" />
              <circle cx="460" cy="500" r="2.5" className="star-pulse" />
            </g>
          </svg>
        </div>

        <div className="hero-shell">
          <div className="hero-copy">
            <p className="hero-brand">
              {COPY.hero.brand}
              <i className="hero-brand-dot" aria-hidden />
            </p>
            <h1>
              {COPY.hero.headlineBefore}{' '}
              <em>{COPY.hero.headlineAccent}</em>
            </h1>
            <p className="hero-lead">{COPY.hero.lead}</p>
            <StoreButtons className="hero-cta" />
            <ClaimGiftButton />
            <p className="hero-note">Free on App Store &amp; Google Play</p>
          </div>

          <div className="hero-visual">
            <PhoneMock />
          </div>
        </div>
      </section>

      <SchoolMarquee />

      <section className="features" id="features">
        <div className="features-inner">
          <header className="features-head">
            <p className="eyebrow">{COPY.features.eyebrow}</p>
            <h2>{COPY.features.title}</h2>
            <p className="section-lead">{COPY.features.lead}</p>
          </header>

          <ol className="feature-list">
            {FEATURES.map((feature, index) => (
              <li key={feature.title} className="feature-item">
                <span className="feature-num">
                  {String(index + 1).padStart(2, '0')}
                </span>
                <div className="feature-copy">
                  <h3>{feature.title}</h3>
                  <p>{feature.body}</p>
                </div>
                <span
                  className="feature-bar"
                  style={{ background: feature.accent }}
                />
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="proof">
        <div className="proof-inner">
          <p className="proof-stat" aria-hidden>
            {COPY.proof.stat}
          </p>
          <h2>{COPY.proof.title}</h2>
          <p className="proof-lead">{COPY.proof.lead}</p>
        </div>
      </section>

      <section className="closing">
        <div className="closing-glow" aria-hidden />
        <div className="closing-inner">
          <h2>{COPY.closing.title}</h2>
          <p>{COPY.closing.lead}</p>
          <StoreButtons />
          <ClaimGiftButton />
        </div>
      </section>
    </div>
  )
}
