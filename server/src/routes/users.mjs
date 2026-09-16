import { listDeletedUsers, listUsers } from '../services/users.mjs'
import { requireAdmin } from '../services/auth_guards.mjs'

export default async function usersRoutes(app) {
  app.get('/api/users', async (req) => {
    await requireAdmin(req)
    const users = await listUsers()
    return { users, total: users.length }
  })

  app.get('/api/users/deleted', async (req) => {
    await requireAdmin(req)
    const users = await listDeletedUsers()
    return { users, total: users.length }
  })
}
