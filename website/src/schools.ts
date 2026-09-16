export type School = {
  name: string
  short: string
  /** 1–3 letter mark shown until a real logo file is added */
  mark: string
  /** Accent for the monogram (original Chkela styling — not a school brand copy) */
  accent: string
  /** Optional path under /schools/ when you drop approved logo files in */
  logo?: string
}

/** Swap `logo` for approved files in `website/public/schools/` when you have them. */
export const SCHOOLS: School[] = [
  {
    name: 'Sandford International School',
    short: 'Sandford',
    mark: 'SF',
    accent: '#7dd3c0',
    logo: '/schools/sandford.png',
  },
  {
    name: 'International Community School',
    short: 'ICS Addis',
    mark: 'ICS',
    accent: '#6ea8ff',
    logo: '/schools/ics.png',
  },
  {
    name: 'Nazareth School',
    short: 'Nazareth',
    mark: 'NZ',
    accent: '#f0a35e',
    logo: '/schools/nazareth.png',
  },
  {
    name: 'St. Joseph School',
    short: 'St. Joseph',
    mark: 'SJ',
    accent: '#8b9cff',
    logo: '/schools/st-joseph.png',
  },
  {
    name: 'Lycée Guébré-Mariam',
    short: 'LGM',
    mark: 'LGM',
    accent: '#e8899a',
    logo: '/schools/lgm.png',
  },
  {
    name: 'Bingham Academy',
    short: 'Bingham',
    mark: 'BA',
    accent: '#c4a35a',
    logo: '/schools/bingham.png',
  },
  {
    name: 'Andinet International School',
    short: 'Andinet',
    mark: 'AD',
    accent: '#5ec4a8',
    logo: '/schools/andinet.png',
  },
  {
    name: 'Ethio Parents’ School',
    short: 'Ethio Parents',
    mark: 'EP',
    accent: '#b794f6',
    logo: '/schools/ethio-parents.png',
  },
  {
    name: 'School of Tomorrow',
    short: 'SOT',
    mark: 'SOT',
    accent: '#5bb8e8',
    logo: '/schools/sot.png',
  },
  {
    name: 'One Planet International',
    short: 'One Planet',
    mark: 'OP',
    accent: '#6bcf7a',
    logo: '/schools/one-planet.png',
  },
  {
    name: 'British International School',
    short: 'BIS Addis',
    mark: 'BIS',
    accent: '#9aa4c7',
    logo: '/schools/bis.png',
  },
  {
    name: 'Gibson Youth Academy',
    short: 'Gibson',
    mark: 'GY',
    accent: '#e0a060',
    logo: '/schools/gibson.png',
  },
]
