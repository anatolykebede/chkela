export type FeedbackEntry = {
  id: string
  message: string
  phone: string | null
  createdAt: string
  status: 'new' | 'read' | 'archived'
}

export type FeedbackFile = {
  items: FeedbackEntry[]
}
