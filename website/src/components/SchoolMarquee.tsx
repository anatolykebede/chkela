import { useState, type CSSProperties } from 'react'
import { SCHOOLS, type School } from '../schools'
import './SchoolMarquee.css'

type Props = {
  heading?: string
}

export function SchoolMarquee({
  heading = 'Our students come from these schools',
}: Props) {
  const track = [...SCHOOLS, ...SCHOOLS]

  return (
    <section className="schools" aria-label={heading}>
      <p className="schools-label">{heading}</p>
      <div className="schools-viewport">
        <ul className="schools-track">
          {track.map((school, index) => (
            <li key={`${school.short}-${index}`} className="schools-item">
              <SchoolMark school={school} />
              <div className="schools-meta">
                <span className="schools-name">{school.short}</span>
                <span className="schools-full">{school.name}</span>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

function SchoolMark({ school }: { school: School }) {
  const [failed, setFailed] = useState(false)

  if (school.logo && !failed) {
    return (
      <span className="schools-mark schools-mark--image">
        <img
          src={school.logo}
          alt=""
          width={44}
          height={44}
          loading="lazy"
          onError={() => setFailed(true)}
        />
      </span>
    )
  }

  return (
    <span
      className="schools-mark"
      style={
        {
          '--school-accent': school.accent,
        } as CSSProperties
      }
      aria-hidden
    >
      <span className="schools-mark-ring" />
      <span className="schools-mark-core">{school.mark}</span>
    </span>
  )
}
