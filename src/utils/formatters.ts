/**
 * Format milliseconds to MM:SS format
 */
export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000)
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
}

/**
 * Format date to readable string
 */
export function formatDate(timestamp: number): string {
  const date = new Date(timestamp)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

/**
 * Format date and time
 */
export function formatDateTime(timestamp: number): string {
  const date = new Date(timestamp)
  return date.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/**
 * Format time only
 */
export function formatTime(timestamp: number): string {
  const date = new Date(timestamp)
  return date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

/**
 * Format file size
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 Bytes'

  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))

  return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i]
}

/**
 * Format weight with decimal places
 */
export function formatWeight(grams: number, decimals: number = 1): string {
  return grams.toFixed(decimals) + 'g'
}

/**
 * Format temperature
 */
export function formatTemperature(celsius: number, decimals: number = 1): string {
  return celsius.toFixed(decimals) + '°C'
}

/**
 * Format pressure
 */
export function formatPressure(bar: number, decimals: number = 1): string {
  return bar.toFixed(decimals) + ' bar'
}

/**
 * Format ratio (e.g., 1:2)
 */
export function formatRatio(dose: number, yield_: number): string {
  if (dose === 0) return '1:0'
  const ratio = yield_ / dose
  return `1:${ratio.toFixed(1)}`
}
