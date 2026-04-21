export interface LunarDateInfo {
  lunarYear: number
  lunarMonth: number
  lunarDay: number
  isLeapMonth: boolean
  monthLabel: string
  dayLabel: string
}

interface LunarDateSnapshot {
  lunarYear: number
  lunarMonth: number
  lunarDay: number
  monthLabel: string
  dayLabel: string
}

export class LunarDateService {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000
  private static readonly formatter: Intl.DateTimeFormat = new Intl.DateTimeFormat('zh-CN-u-ca-chinese', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    timeZone: 'Asia/Shanghai'
  })
  private static readonly monthNumberMap: Record<string, number> = {
    '\u6b63\u6708': 1,
    '\u4e00\u6708': 1,
    '\u4e8c\u6708': 2,
    '\u4e09\u6708': 3,
    '\u56db\u6708': 4,
    '\u4e94\u6708': 5,
    '\u516d\u6708': 6,
    '\u4e03\u6708': 7,
    '\u516b\u6708': 8,
    '\u4e5d\u6708': 9,
    '\u5341\u6708': 10,
    '\u51ac\u6708': 11,
    '\u5341\u4e00\u6708': 11,
    '\u814a\u6708': 12,
    '\u5341\u4e8c\u6708': 12
  }
  private static readonly dayNumberMap: Record<string, number> = {
    '\u521d\u4e00': 1,
    '\u521d\u4e8c': 2,
    '\u521d\u4e09': 3,
    '\u521d\u56db': 4,
    '\u521d\u4e94': 5,
    '\u521d\u516d': 6,
    '\u521d\u4e03': 7,
    '\u521d\u516b': 8,
    '\u521d\u4e5d': 9,
    '\u521d\u5341': 10,
    '\u5341\u4e00': 11,
    '\u5341\u4e8c': 12,
    '\u5341\u4e09': 13,
    '\u5341\u56db': 14,
    '\u5341\u4e94': 15,
    '\u5341\u516d': 16,
    '\u5341\u4e03': 17,
    '\u5341\u516b': 18,
    '\u5341\u4e5d': 19,
    '\u4e8c\u5341': 20,
    '\u5eff\u4e00': 21,
    '\u5eff\u4e8c': 22,
    '\u5eff\u4e09': 23,
    '\u5eff\u56db': 24,
    '\u5eff\u4e94': 25,
    '\u5eff\u516d': 26,
    '\u5eff\u4e03': 27,
    '\u5eff\u516b': 28,
    '\u5eff\u4e5d': 29,
    '\u4e09\u5341': 30
  }
  private static readonly infoCache: Map<string, LunarDateInfo> = new Map<string, LunarDateInfo>()
  private static readonly leapMonthCache: Map<string, boolean> = new Map<string, boolean>()

  static getLunarDateInfo(source: Date | number): LunarDateInfo {
    const date = LunarDateService.startOfDay(source)
    const cacheKey = LunarDateService.buildDateKey(date)
    const cached = LunarDateService.infoCache.get(cacheKey)
    if (cached) {
      return cached
    }

    const snapshot = LunarDateService.getSnapshot(date)
    const monthStart = LunarDateService.findCurrentMonthStart(date, snapshot)
    const isLeapMonth = LunarDateService.isLeapMonthStart(monthStart, snapshot.lunarYear, snapshot.lunarMonth)
    const info: LunarDateInfo = {
      lunarYear: snapshot.lunarYear,
      lunarMonth: snapshot.lunarMonth,
      lunarDay: snapshot.lunarDay,
      isLeapMonth: isLeapMonth,
      monthLabel: snapshot.monthLabel.replace(/^\u95f0/, ''),
      dayLabel: snapshot.dayLabel
    }
    LunarDateService.infoCache.set(cacheKey, info)
    return info
  }

  static hasLeapMonthInYear(lunarYear: number, lunarMonth: number): boolean {
    const cacheKey = `${lunarYear}-${lunarMonth}`
    const cached = LunarDateService.leapMonthCache.get(cacheKey)
    if (cached !== undefined) {
      return cached
    }

    const scanStart = new Date(lunarYear - 1, 11, 1)
    const scanEnd = new Date(lunarYear + 1, 2, 1)
    let cursor = LunarDateService.startOfDay(scanStart)
    let found = false
    while (cursor.getTime() <= scanEnd.getTime()) {
      const info = LunarDateService.getLunarDateInfo(cursor)
      if (info.lunarYear === lunarYear && info.lunarMonth === lunarMonth && info.isLeapMonth) {
        found = true
        break
      }
      cursor = new Date(cursor.getTime() + LunarDateService.DAY_MS)
    }

    LunarDateService.leapMonthCache.set(cacheKey, found)
    return found
  }

  static buildDisplayText(info: LunarDateInfo): string {
    const leapText = info.isLeapMonth ? '\u95f0' : ''
    return `\u519c\u5386${leapText}${info.monthLabel}${info.dayLabel}`
  }

  static startOfDay(source: Date | number): Date {
    const date = source instanceof Date ? new Date(source.getTime()) : new Date(source)
    date.setHours(0, 0, 0, 0)
    return date
  }

  private static getSnapshot(source: Date | number): LunarDateSnapshot {
    const date = LunarDateService.startOfDay(source)
    const parts = LunarDateService.formatter.formatToParts(date)
    const relatedYearPart = parts.find((part: Intl.DateTimeFormatPart) => `${part.type}` === 'relatedYear')
    const relatedYear = Number(relatedYearPart?.value ?? '0')
    const rawMonthLabel = parts.find((part: Intl.DateTimeFormatPart) => part.type === 'month')?.value ?? ''
    const rawDayLabel = parts.find((part: Intl.DateTimeFormatPart) => part.type === 'day')?.value ?? ''
    const monthLabel = rawMonthLabel.replace(/^\u95f0/, '')
    const lunarMonth = LunarDateService.monthNumberMap[monthLabel] ?? 0
    const lunarDay = LunarDateService.parseLunarDay(rawDayLabel)
    const dayLabel = LunarDateService.normalizeDayLabel(rawDayLabel, lunarDay)
    return {
      lunarYear: relatedYear,
      lunarMonth: lunarMonth,
      lunarDay: lunarDay,
      monthLabel: monthLabel,
      dayLabel: dayLabel
    }
  }

  private static findCurrentMonthStart(date: Date, snapshot: LunarDateSnapshot): Date {
    let cursor = new Date(date.getTime())
    while (true) {
      const info = LunarDateService.getSnapshot(cursor)
      if (info.lunarDay === 1) {
        return cursor
      }
      cursor = new Date(cursor.getTime() - LunarDateService.DAY_MS)
      const daysDiff = Math.round((date.getTime() - cursor.getTime()) / LunarDateService.DAY_MS)
      if (daysDiff > 32) {
        return date
      }
      if (info.lunarYear !== snapshot.lunarYear || info.lunarMonth !== snapshot.lunarMonth) {
        return date
      }
    }
  }

  private static isLeapMonthStart(monthStart: Date, lunarYear: number, lunarMonth: number): boolean {
    let cursor = new Date(monthStart.getTime() - LunarDateService.DAY_MS)
    for (let index = 0; index < 35; index++) {
      const info = LunarDateService.getSnapshot(cursor)
      if (info.lunarYear !== lunarYear) {
        return false
      }
      if (info.lunarDay === 1 && info.lunarMonth === lunarMonth) {
        return true
      }
      cursor = new Date(cursor.getTime() - LunarDateService.DAY_MS)
    }
    return false
  }

  private static parseLunarDay(rawDayLabel: string): number {
    if (/^\d+$/.test(rawDayLabel)) {
      return Number(rawDayLabel)
    }
    return LunarDateService.dayNumberMap[rawDayLabel] ?? 0
  }

  private static normalizeDayLabel(rawDayLabel: string, lunarDay: number): string {
    if (LunarDateService.dayNumberMap[rawDayLabel] !== undefined) {
      return rawDayLabel
    }
    const entry = Object.entries(LunarDateService.dayNumberMap).find((item: [string, number]) => item[1] === lunarDay)
    return entry?.[0] ?? rawDayLabel
  }

  private static buildDateKey(date: Date): string {
    const year = date.getFullYear()
    const month = `${date.getMonth() + 1}`.padStart(2, '0')
    const day = `${date.getDate()}`.padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}
