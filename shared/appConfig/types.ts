export type AppContactConfig = {
  supportEmail: string
  supportPhoneDisplay: string
  supportPhoneTel: string
  website: string
  telegramUsername: string
}

export type AppSocialConfig = {
  instagramUrl: string
  tiktokUrl: string
  youtubeUrl: string
  facebookUrl: string
  xUrl: string
}

export type AppConfig = {
  contact: AppContactConfig
  social: AppSocialConfig
  updatedAt: string | null
}

export const DEFAULT_APP_CONFIG: AppConfig = {
  contact: {
    supportEmail: 'contact@chkela.com',
    supportPhoneDisplay: '+251 947 819 388',
    supportPhoneTel: '+251947819388',
    website: 'https://www.chkela.com',
    telegramUsername: 'chkelaadmin',
  },
  social: {
    instagramUrl: 'https://www.instagram.com/chkela.app',
    tiktokUrl: 'https://www.tiktok.com/@chkela.app',
    youtubeUrl: 'https://www.youtube.com/@chkela',
    facebookUrl: 'https://www.facebook.com/chkela.app',
    xUrl: 'https://x.com/chkela_app',
  },
  updatedAt: null,
}
