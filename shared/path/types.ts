export type PathPublishStatus = 'draft' | 'published'
export type PathLevelKind = 'standard' | 'checkpoint' | 'boss'
export type PathChallengeType =
  | 'strike'
  | 'blitz'
  | 'link'
  | 'sequence'
  | 'answer'

export type PathLevel = {
  id: string
  number: number
  title: string
  kind: PathLevelKind
  subject: string
  /** `grade-9` … `grade-12` */
  gradeId: string
  xpReward: number
  competency: string
  skillTag: string
  hook: string
  lessonId?: string
  arenaLabel?: string
  status: PathPublishStatus
  updatedAt?: string
}

export type PathChallenge = {
  id: string
  levelId: string
  order: number
  type: PathChallengeType
  skillTag: string
  waveLabel: string
  status: PathPublishStatus
  updatedAt?: string
  // strike
  prompt?: string
  options?: string[]
  correctIndex?: number
  // blitz
  isTrue?: boolean
  seconds?: number
  // link
  pairs?: Record<string, string>
  // sequence
  title?: string
  stepsInOrder?: string[]
  // answer (works for all subjects: number or short text)
  correctAnswer?: string
  acceptedAnswers?: string[]
  hint?: string
  inputKind?: 'any' | 'number' | 'text'
}

export type PathCatalog = {
  levels: PathLevel[]
  challenges: PathChallenge[]
}
