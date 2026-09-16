import { ClaimGiftButton } from '../components/ClaimGiftButton'
import { StoreButtons } from '../components/StoreButtons'
import './AboutPage.css'

export function AboutPage() {
  return (
    <div className="about">
      <section className="about-hero">
        <p className="eyebrow">About Chkela</p>
        <h1>Smarter prep for the exam that matters.</h1>
        <p className="about-lead">
          Matric is high stakes. Grinding harder isn’t a strategy. Chkela helps
          Ethiopian Grade 12 students study with focus — real past papers, clear
          feedback, and tools that turn limited time into real score gains.
        </p>
      </section>

      <section className="about-body">
        <div className="about-block">
          <h2>Why smarter beats harder</h2>
          <p>
            Most students already work hard. What’s missing is direction: which
            topics matter, which questions match the exam, and how to spend the
            next hour so it actually raises the mark. Chkela was built to answer
            that — every session.
          </p>
        </div>
        <div className="about-block">
          <h2>What we put in your hands</h2>
          <p>
            Past papers that mirror exam day. Analytics that surface weak spots.
            Short daily practice that sticks. Notes aligned to the syllabus. And
            help when you’re stuck — so you keep moving instead of spinning.
          </p>
        </div>
        <div className="about-block">
          <h2>Built in Ethiopia</h2>
          <p>
            Made for Ethiopian students, schools, and families who care about
            results. If you want more learners preparing with focus — not
            burnout — we’d love to talk.
          </p>
        </div>
        <div className="about-block">
          <h2>Get in touch</h2>
          <p>
            Email{' '}
            <a href="mailto:contact@chkela.com">contact@chkela.com</a> or call{' '}
            <a href="tel:+251947819388">+251 947 819 388</a>.
          </p>
        </div>
      </section>

      <section className="about-cta">
        <h2>Start studying smarter today.</h2>
        <StoreButtons />
        <ClaimGiftButton />
      </section>
    </div>
  )
}
