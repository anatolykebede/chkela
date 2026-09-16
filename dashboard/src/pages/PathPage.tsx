import { useCallback, useEffect, useMemo, useState, type FormEvent } from 'react'
import { Map, Plus, Trash2 } from 'lucide-react'
import { PageHeader } from '../components/PageHeader'
import { Badge } from '../components/Badge'
import {
  deletePathItem,
  fetchPathCatalog,
  upsertPathChallenge,
  upsertPathLevel,
  type PathChallenge,
  type PathChallengeType,
  type PathLevel,
  type PathLevelKind,
} from '../lib/pathApi'
import '../components/DataTable.css'
import './Pages.css'
import './PathPage.css'

const KINDS: PathLevelKind[] = ['standard', 'checkpoint', 'boss']
const TYPES: PathChallengeType[] = [
  'strike',
  'blitz',
  'link',
  'sequence',
  'answer',
]

const emptyLevel = (): Partial<PathLevel> => ({
  number: 1,
  title: '',
  kind: 'standard',
  subject: 'Biology',
  gradeId: 'grade-9',
  xpReward: 25,
  competency: '',
  skillTag: '',
  hook: '',
  lessonId: '',
  arenaLabel: '',
  status: 'published',
})

const GRADE_OPTIONS = [
  { id: 'grade-9', label: 'Grade 9' },
  { id: 'grade-10', label: 'Grade 10' },
  { id: 'grade-11', label: 'Grade 11' },
  { id: 'grade-12', label: 'Grade 12' },
] as const

function emptyChallenge(levelId: string): Partial<PathChallenge> {
  return {
    levelId,
    order: 1,
    type: 'strike',
    skillTag: '',
    waveLabel: 'STRIKE',
    status: 'published',
    prompt: '',
    options: ['', '', '', ''],
    correctIndex: 0,
    isTrue: true,
    seconds: 8,
    pairs: { '': '' },
    title: '',
    stepsInOrder: ['', ''],
    correctAnswer: '',
    acceptedAnswers: [''],
    hint: '',
    inputKind: 'any',
  }
}

export function PathPage() {
  const [filterGrade, setFilterGrade] = useState<string>('all')
  const [levels, setLevels] = useState<PathLevel[]>([])
  const [challenges, setChallenges] = useState<PathChallenge[]>([])
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [levelForm, setLevelForm] = useState<Partial<PathLevel>>(emptyLevel())
  const [challengeForm, setChallengeForm] = useState<Partial<PathChallenge>>(
    emptyChallenge(''),
  )
  const [editingChallengeId, setEditingChallengeId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const refresh = useCallback(async () => {
    setError('')
    try {
      const catalog = await fetchPathCatalog()
      setLevels(catalog.levels)
      setChallenges(catalog.challenges)
      setSelectedId((prev) => {
        if (prev && catalog.levels.some((l) => l.id === prev)) return prev
        return catalog.levels[0]?.id ?? null
      })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load Path catalog')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const visibleLevels = useMemo(() => {
    if (filterGrade === 'all') return levels
    return levels.filter((l) => (l.gradeId || 'grade-9') === filterGrade)
  }, [levels, filterGrade])

  const selected = useMemo(
    () => levels.find((l) => l.id === selectedId) ?? null,
    [levels, selectedId],
  )

  const levelChallenges = useMemo(
    () =>
      challenges
        .filter((c) => c.levelId === selectedId)
        .sort((a, b) => a.order - b.order),
    [challenges, selectedId],
  )

  function startNewLevel() {
    setLevelForm({
      ...emptyLevel(),
      number: (levels[levels.length - 1]?.number ?? 0) + 1,
    })
    setSelectedId(null)
    setEditingChallengeId(null)
    setChallengeForm(emptyChallenge(''))
  }

  function selectLevel(level: PathLevel) {
    setSelectedId(level.id)
    setLevelForm({ ...level })
    setEditingChallengeId(null)
    setChallengeForm(emptyChallenge(level.id))
  }

  async function saveLevel(event: FormEvent) {
    event.preventDefault()
    if (!levelForm.title?.trim()) {
      setError('Gate title is required')
      return
    }
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const item = await upsertPathLevel({
        ...levelForm,
        title: levelForm.title.trim(),
      } as PathLevel & { title: string })
      setNotice(`Saved gate ${item.number}: ${item.title}`)
      await refresh()
      setSelectedId(item.id)
      setLevelForm({ ...item })
      setChallengeForm(emptyChallenge(item.id))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save gate')
    } finally {
      setSaving(false)
    }
  }

  async function removeLevel(id: string) {
    if (!confirm('Delete this gate and all its challenges?')) return
    setSaving(true)
    setError('')
    try {
      await deletePathItem('levels', id)
      setNotice('Gate deleted')
      await refresh()
      startNewLevel()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete gate')
    } finally {
      setSaving(false)
    }
  }

  function editChallenge(challenge: PathChallenge) {
    setEditingChallengeId(challenge.id)
    setChallengeForm({
      ...emptyChallenge(challenge.levelId),
      ...challenge,
      options: challenge.options?.length
        ? [...challenge.options]
        : ['', '', '', ''],
      pairs: challenge.pairs && Object.keys(challenge.pairs).length
        ? { ...challenge.pairs }
        : { '': '' },
      stepsInOrder: challenge.stepsInOrder?.length
        ? [...challenge.stepsInOrder]
        : ['', ''],
    })
  }

  function startNewChallenge() {
    if (!selected) return
    setEditingChallengeId(null)
    setChallengeForm({
      ...emptyChallenge(selected.id),
      order: levelChallenges.length + 1,
      skillTag: selected.skillTag,
    })
  }

  async function saveChallenge(event: FormEvent) {
    event.preventDefault()
    if (!selected) {
      setError('Select or save a gate first')
      return
    }
    setSaving(true)
    setError('')
    setNotice('')
    try {
      const payload: Partial<PathChallenge> & {
        levelId: string
        type: PathChallengeType
      } = {
        ...challengeForm,
        id: editingChallengeId ?? undefined,
        levelId: selected.id,
        type: (challengeForm.type || 'strike') as PathChallengeType,
        skillTag: challengeForm.skillTag || selected.skillTag,
        waveLabel:
          challengeForm.waveLabel ||
          String(challengeForm.type || 'strike').toUpperCase(),
      }
      const item = await upsertPathChallenge(payload)
      setNotice(`Saved ${item.type} wave #${item.order}`)
      await refresh()
      startNewChallenge()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save challenge')
    } finally {
      setSaving(false)
    }
  }

  async function removeChallenge(id: string) {
    if (!confirm('Delete this challenge wave?')) return
    setSaving(true)
    try {
      await deletePathItem('challenges', id)
      setNotice('Challenge deleted')
      await refresh()
      startNewChallenge()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not delete challenge')
    } finally {
      setSaving(false)
    }
  }

  const pairEntries = Object.entries(challengeForm.pairs || { '': '' })

  return (
    <div className="page path-admin">
      <PageHeader
        title="The Path"
        subtitle="Build arena gates and combat waves (Strike, Blitz, Link, Sequence, Answer)."
      />

      {error ? <p className="path-admin__banner path-admin__banner--error">{error}</p> : null}
      {notice ? <p className="path-admin__banner path-admin__banner--ok">{notice}</p> : null}

      <div className="path-admin-stats">
        <div className="path-admin-stat">
          <span>Gates</span>
          <strong>{levels.length}</strong>
        </div>
        <div className="path-admin-stat">
          <span>Waves</span>
          <strong>{challenges.length}</strong>
        </div>
        <div className="path-admin-stat">
          <span>Bosses</span>
          <strong>{levels.filter((l) => l.kind === 'boss').length}</strong>
        </div>
        <div className="path-admin-stat">
          <span>Published</span>
          <strong>{levels.filter((l) => l.status === 'published').length}</strong>
        </div>
      </div>

      {loading ? (
        <p className="path-admin__muted">Loading Path catalog…</p>
      ) : (
        <div className="path-admin-grid">
          <section className="panel path-admin-panel">
            <div className="path-admin-panel__head">
              <h2 className="panel__title">Gates</h2>
              <button type="button" className="btn-ghost" onClick={startNewLevel}>
                <Plus size={16} /> New gate
              </button>
            </div>
            <label className="path-admin-filter">
              Grade filter
              <select
                value={filterGrade}
                onChange={(e) => setFilterGrade(e.target.value)}
              >
                <option value="all">All grades</option>
                {GRADE_OPTIONS.map((g) => (
                  <option key={g.id} value={g.id}>
                    {g.label}
                  </option>
                ))}
              </select>
            </label>
            <ul className="path-admin-levels">
              {visibleLevels.map((level) => (
                <li key={level.id}>
                  <button
                    type="button"
                    className={`path-admin-level${
                      selectedId === level.id ? ' path-admin-level--active' : ''
                    }`}
                    onClick={() => selectLevel(level)}
                  >
                    <span className="path-admin-level__num">{level.number}</span>
                    <span className="path-admin-level__body">
                      <strong>{level.title}</strong>
                      <small>
                        {level.gradeId || 'grade-9'} · {level.kind} · {level.xpReward}{' '}
                        XP
                      </small>
                    </span>
                    <Badge
                      tone={
                        level.kind === 'boss'
                          ? 'warning'
                          : level.kind === 'checkpoint'
                            ? 'accent'
                            : 'neutral'
                      }
                    >
                      {level.kind}
                    </Badge>
                  </button>
                </li>
              ))}
              {visibleLevels.length === 0 ? (
                <li className="path-admin__muted">No gates yet. Create the first one.</li>
              ) : null}
            </ul>
          </section>

          <section className="panel path-admin-panel">
            <div className="path-admin-panel__head">
              <h2 className="panel__title">
                <Map size={16} /> Gate editor
              </h2>
              {selected ? (
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => void removeLevel(selected.id)}
                  disabled={saving}
                >
                  <Trash2 size={16} /> Delete
                </button>
              ) : null}
            </div>

            <form className="path-admin-form" onSubmit={saveLevel}>
              <div className="path-admin-form__grid">
                <label>
                  Number
                  <input
                    type="number"
                    min={1}
                    value={levelForm.number ?? 1}
                    onChange={(e) =>
                      setLevelForm((f) => ({ ...f, number: Number(e.target.value) }))
                    }
                  />
                </label>
                <label>
                  Grade
                  <select
                    value={levelForm.gradeId || 'grade-9'}
                    onChange={(e) =>
                      setLevelForm((f) => ({ ...f, gradeId: e.target.value }))
                    }
                  >
                    {GRADE_OPTIONS.map((g) => (
                      <option key={g.id} value={g.id}>
                        {g.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Kind
                  <select
                    value={levelForm.kind || 'standard'}
                    onChange={(e) =>
                      setLevelForm((f) => ({
                        ...f,
                        kind: e.target.value as PathLevelKind,
                      }))
                    }
                  >
                    {KINDS.map((k) => (
                      <option key={k} value={k}>
                        {k}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  XP
                  <input
                    type="number"
                    min={1}
                    value={levelForm.xpReward ?? 25}
                    onChange={(e) =>
                      setLevelForm((f) => ({
                        ...f,
                        xpReward: Number(e.target.value),
                      }))
                    }
                  />
                </label>
                <label>
                  Status
                  <select
                    value={levelForm.status || 'published'}
                    onChange={(e) =>
                      setLevelForm((f) => ({
                        ...f,
                        status: e.target.value as PathLevel['status'],
                      }))
                    }
                  >
                    <option value="published">published</option>
                    <option value="draft">draft</option>
                  </select>
                </label>
              </div>

              <label>
                Title
                <input
                  value={levelForm.title || ''}
                  onChange={(e) =>
                    setLevelForm((f) => ({ ...f, title: e.target.value }))
                  }
                  placeholder="Define Biology"
                  required
                />
              </label>

              <div className="path-admin-form__grid">
                <label>
                  Subject
                  <input
                    value={levelForm.subject || ''}
                    onChange={(e) =>
                      setLevelForm((f) => ({ ...f, subject: e.target.value }))
                    }
                  />
                </label>
                <label>
                  Skill tag
                  <input
                    value={levelForm.skillTag || ''}
                    onChange={(e) =>
                      setLevelForm((f) => ({ ...f, skillTag: e.target.value }))
                    }
                    placeholder="define-biology"
                  />
                </label>
              </div>

              <label>
                Competency
                <input
                  value={levelForm.competency || ''}
                  onChange={(e) =>
                    setLevelForm((f) => ({ ...f, competency: e.target.value }))
                  }
                />
              </label>

              <label>
                Hook (pre-battle tip)
                <textarea
                  rows={3}
                  value={levelForm.hook || ''}
                  onChange={(e) =>
                    setLevelForm((f) => ({ ...f, hook: e.target.value }))
                  }
                />
              </label>

              <div className="path-admin-form__grid">
                <label>
                  Lesson ID (optional)
                  <input
                    value={levelForm.lessonId || ''}
                    onChange={(e) =>
                      setLevelForm((f) => ({ ...f, lessonId: e.target.value }))
                    }
                    placeholder="bio9-ch1-l1"
                  />
                </label>
                <label>
                  Arena label (optional)
                  <input
                    value={levelForm.arenaLabel || ''}
                    onChange={(e) =>
                      setLevelForm((f) => ({ ...f, arenaLabel: e.target.value }))
                    }
                    placeholder="ARENA I · UNIT 1"
                  />
                </label>
              </div>

              <button type="submit" className="btn-primary" disabled={saving}>
                {selected ? 'Update gate' : 'Create gate'}
              </button>
            </form>
          </section>

          <section className="panel path-admin-panel path-admin-panel--wide">
            <div className="path-admin-panel__head">
              <h2 className="panel__title">
                Combat waves {selected ? `· ${selected.title}` : ''}
              </h2>
              <button
                type="button"
                className="btn-ghost"
                onClick={startNewChallenge}
                disabled={!selected}
              >
                <Plus size={16} /> New wave
              </button>
            </div>

            {!selected ? (
              <p className="path-admin__muted">Select a gate to edit its waves.</p>
            ) : (
              <div className="path-admin-waves">
                <ul className="path-admin-wave-list">
                  {levelChallenges.map((c) => (
                    <li key={c.id}>
                      <button
                        type="button"
                        className={`path-admin-wave${
                          editingChallengeId === c.id
                            ? ' path-admin-wave--active'
                            : ''
                        }`}
                        onClick={() => editChallenge(c)}
                      >
                        <Badge tone="accent">{c.type}</Badge>
                        <span>
                          #{c.order} {c.waveLabel}
                          <small>{c.prompt || c.title || 'Link / Sequence'}</small>
                        </span>
                      </button>
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() => void removeChallenge(c.id)}
                        aria-label="Delete wave"
                      >
                        <Trash2 size={14} />
                      </button>
                    </li>
                  ))}
                  {levelChallenges.length === 0 ? (
                    <li className="path-admin__muted">No waves yet for this gate.</li>
                  ) : null}
                </ul>

                <form className="path-admin-form" onSubmit={saveChallenge}>
                  <div className="path-admin-form__grid">
                    <label>
                      Type
                      <select
                        value={challengeForm.type || 'strike'}
                        onChange={(e) => {
                          const type = e.target.value as PathChallengeType
                          setChallengeForm((f) => ({
                            ...f,
                            type,
                            waveLabel: type.toUpperCase(),
                          }))
                        }}
                      >
                        {TYPES.map((t) => (
                          <option key={t} value={t}>
                            {t}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label>
                      Order
                      <input
                        type="number"
                        min={1}
                        value={challengeForm.order ?? 1}
                        onChange={(e) =>
                          setChallengeForm((f) => ({
                            ...f,
                            order: Number(e.target.value),
                          }))
                        }
                      />
                    </label>
                    <label>
                      Skill tag
                      <input
                        value={challengeForm.skillTag || ''}
                        onChange={(e) =>
                          setChallengeForm((f) => ({
                            ...f,
                            skillTag: e.target.value,
                          }))
                        }
                      />
                    </label>
                    <label>
                      Wave label
                      <input
                        value={challengeForm.waveLabel || ''}
                        onChange={(e) =>
                          setChallengeForm((f) => ({
                            ...f,
                            waveLabel: e.target.value,
                          }))
                        }
                      />
                    </label>
                  </div>

                  {challengeForm.type === 'strike' ||
                  challengeForm.type === 'blitz' ||
                  challengeForm.type === 'answer' ? (
                    <label>
                      Prompt
                      <textarea
                        rows={2}
                        value={challengeForm.prompt || ''}
                        onChange={(e) =>
                          setChallengeForm((f) => ({ ...f, prompt: e.target.value }))
                        }
                        required
                      />
                    </label>
                  ) : null}

                  {challengeForm.type === 'answer' ? (
                    <div>
                      <div className="path-admin-form__grid">
                        <label>
                          Correct answer
                          <input
                            value={challengeForm.correctAnswer || ''}
                            onChange={(e) =>
                              setChallengeForm((f) => ({
                                ...f,
                                correctAnswer: e.target.value,
                              }))
                            }
                            placeholder="4 or mitochondria"
                            required
                          />
                        </label>
                        <label>
                          Input kind
                          <select
                            value={challengeForm.inputKind || 'any'}
                            onChange={(e) =>
                              setChallengeForm((f) => ({
                                ...f,
                                inputKind: e.target.value as
                                  | 'any'
                                  | 'number'
                                  | 'text',
                              }))
                            }
                          >
                            <option value="any">any (number or text)</option>
                            <option value="number">number</option>
                            <option value="text">text</option>
                          </select>
                        </label>
                      </div>
                      <label>
                        Hint (optional)
                        <input
                          value={challengeForm.hint || ''}
                          onChange={(e) =>
                            setChallengeForm((f) => ({ ...f, hint: e.target.value }))
                          }
                        />
                      </label>
                      <p className="path-admin-section-title">
                        Also accept (optional alternatives)
                      </p>
                      {(challengeForm.acceptedAnswers || ['']).map((ans, i) => (
                        <input
                          key={i}
                          value={ans}
                          placeholder={`Alt ${i + 1}`}
                          onChange={(e) => {
                            const next = [...(challengeForm.acceptedAnswers || [])]
                            next[i] = e.target.value
                            setChallengeForm((f) => ({
                              ...f,
                              acceptedAnswers: next,
                            }))
                          }}
                          style={{ marginBottom: 8 }}
                        />
                      ))}
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() =>
                          setChallengeForm((f) => ({
                            ...f,
                            acceptedAnswers: [...(f.acceptedAnswers || []), ''],
                          }))
                        }
                      >
                        Add alternative
                      </button>
                    </div>
                  ) : null}

                  {challengeForm.type === 'strike' ? (
                    <div className="path-admin-options">
                      <p className="path-admin-section-title">Options</p>
                      {(challengeForm.options || ['', '', '', '']).map((opt, i) => (
                        <label key={i} className="path-admin-option-row">
                          <input
                            type="radio"
                            name="correct"
                            checked={(challengeForm.correctIndex ?? 0) === i}
                            onChange={() =>
                              setChallengeForm((f) => ({ ...f, correctIndex: i }))
                            }
                          />
                          <input
                            value={opt}
                            onChange={(e) => {
                              const options = [...(challengeForm.options || [])]
                              options[i] = e.target.value
                              setChallengeForm((f) => ({ ...f, options }))
                            }}
                            placeholder={`Option ${i + 1}`}
                            required
                          />
                        </label>
                      ))}
                    </div>
                  ) : null}

                  {challengeForm.type === 'blitz' ? (
                    <div className="path-admin-form__grid">
                      <label>
                        Answer
                        <select
                          value={challengeForm.isTrue ? 'true' : 'false'}
                          onChange={(e) =>
                            setChallengeForm((f) => ({
                              ...f,
                              isTrue: e.target.value === 'true',
                            }))
                          }
                        >
                          <option value="true">TRUE</option>
                          <option value="false">FALSE</option>
                        </select>
                      </label>
                      <label>
                        Seconds
                        <input
                          type="number"
                          min={3}
                          value={challengeForm.seconds ?? 8}
                          onChange={(e) =>
                            setChallengeForm((f) => ({
                              ...f,
                              seconds: Number(e.target.value),
                            }))
                          }
                        />
                      </label>
                    </div>
                  ) : null}

                  {challengeForm.type === 'link' ? (
                    <div>
                      <p className="path-admin-section-title">Pairs (left → right)</p>
                      {pairEntries.map(([left, right], i) => (
                        <div key={i} className="path-admin-pair-row">
                          <input
                            value={left}
                            placeholder="Term"
                            onChange={(e) => {
                              const entries = [...pairEntries]
                              entries[i] = [e.target.value, right]
                              setChallengeForm((f) => ({
                                ...f,
                                pairs: Object.fromEntries(entries),
                              }))
                            }}
                          />
                          <input
                            value={right}
                            placeholder="Meaning"
                            onChange={(e) => {
                              const entries = [...pairEntries]
                              entries[i] = [left, e.target.value]
                              setChallengeForm((f) => ({
                                ...f,
                                pairs: Object.fromEntries(entries),
                              }))
                            }}
                          />
                        </div>
                      ))}
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() =>
                          setChallengeForm((f) => ({
                            ...f,
                            pairs: { ...(f.pairs || {}), '': '' },
                          }))
                        }
                      >
                        Add pair
                      </button>
                    </div>
                  ) : null}

                  {challengeForm.type === 'sequence' ? (
                    <div>
                      <label>
                        Sequence title
                        <input
                          value={challengeForm.title || ''}
                          onChange={(e) =>
                            setChallengeForm((f) => ({ ...f, title: e.target.value }))
                          }
                          required
                        />
                      </label>
                      <p className="path-admin-section-title">Steps in order</p>
                      {(challengeForm.stepsInOrder || ['']).map((step, i) => (
                        <input
                          key={i}
                          value={step}
                          placeholder={`Step ${i + 1}`}
                          onChange={(e) => {
                            const steps = [...(challengeForm.stepsInOrder || [])]
                            steps[i] = e.target.value
                            setChallengeForm((f) => ({ ...f, stepsInOrder: steps }))
                          }}
                          style={{ marginBottom: 8 }}
                        />
                      ))}
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() =>
                          setChallengeForm((f) => ({
                            ...f,
                            stepsInOrder: [...(f.stepsInOrder || []), ''],
                          }))
                        }
                      >
                        Add step
                      </button>
                    </div>
                  ) : null}

                  <button type="submit" className="btn-primary" disabled={saving || !selected}>
                    {editingChallengeId ? 'Update wave' : 'Add wave'}
                  </button>
                </form>
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  )
}
