import { adminFetch } from './adminAuth'

export type StudentStatus = 'active' | 'inactive'

export type Student = {
  id: string
  name: string
  phone: string
  status: StudentStatus
}

export async function listStudents(): Promise<Student[]> {
  const response = await adminFetch('/api/students')
  const data = (await response.json()) as {
    students?: Student[]
    error?: string
  }
  if (!response.ok) throw new Error(data.error || 'Failed to load students')
  return data.students || []
}

export async function upsertStudent(input: {
  name: string
  phone: string
  status?: StudentStatus
}): Promise<Student> {
  const response = await adminFetch('/api/students', {
    method: 'POST',
    body: JSON.stringify(input),
  })
  const data = (await response.json()) as { student?: Student; error?: string }
  if (!response.ok || !data.student) {
    throw new Error(data.error || 'Failed to save student')
  }
  return data.student
}
