import logo from '../assets/logo.png'
import './PhoneMock.css'

export function PhoneMock() {
  return (
    <div className="phone" aria-hidden>
      <div className="phone-glow" />
      <div className="phone-ring" />
      <div className="phone-frame">
        <div className="phone-island" />
        <div className="phone-screen">
          <div className="phone-status">
            <span>9:41</span>
            <span className="phone-signal" />
          </div>

          <div className="phone-header">
            <img src={logo} alt="" width={40} height={40} />
            <div>
              <strong>Chkela</strong>
              <span>Smarter matric prep</span>
            </div>
            <span className="phone-live">Focus</span>
          </div>

          <div className="phone-subjects">
            <span className="is-active">Weak: Physics</span>
            <span>Math</span>
            <span>Biology</span>
          </div>

          <div className="phone-chat">
            <div className="bubble bubble--ai">
              You’re missing marks on Newton’s laws. Want a 5-question drill?
            </div>
            <div className="bubble bubble--user">Yes — past paper style</div>
            <div className="bubble bubble--ai">
              Done. 5 questions from recent NEAEA papers. Finish these before
              revisiting notes.
            </div>
          </div>

          <div className="phone-composer">
            <span>What should I practice next?</span>
            <span className="phone-send" />
          </div>
        </div>
      </div>
    </div>
  )
}
