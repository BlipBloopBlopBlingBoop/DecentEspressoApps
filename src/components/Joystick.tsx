import { useRef, useEffect, useState } from 'react'
import { Activity } from 'lucide-react'

interface JoystickProps {
  onUpdate: (x: number, y: number) => void // x: -1 to 1 (flow), y: -1 to 1 (pressure)
  size?: number
  disabled?: boolean
}

export default function Joystick({ onUpdate, size = 200, disabled = false }: JoystickProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [position, setPosition] = useState({ x: 0, y: 0 }) // -1 to 1 normalized
  const [isDragging, setIsDragging] = useState(false)

  const maxDistance = size / 2 - 20 // Max distance from center

  const updatePosition = (clientX: number, clientY: number) => {
    if (!containerRef.current || disabled) return

    const rect = containerRef.current.getBoundingClientRect()
    const centerX = rect.left + rect.width / 2
    const centerY = rect.top + rect.height / 2

    // Calculate distance from center
    let deltaX = clientX - centerX
    let deltaY = clientY - centerY

    // Calculate distance and limit to maxDistance
    const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if (distance > maxDistance) {
      const angle = Math.atan2(deltaY, deltaX)
      deltaX = Math.cos(angle) * maxDistance
      deltaY = Math.sin(angle) * maxDistance
    }

    // Normalize to -1 to 1
    const normalizedX = deltaX / maxDistance
    const normalizedY = -deltaY / maxDistance // Invert Y so up is positive

    setPosition({ x: normalizedX, y: normalizedY })
    onUpdate(normalizedX, normalizedY)
  }

  const handleStart = (clientX: number, clientY: number) => {
    if (disabled) return
    setIsDragging(true)
    updatePosition(clientX, clientY)
  }

  const handleMove = (clientX: number, clientY: number) => {
    if (!isDragging || disabled) return
    updatePosition(clientX, clientY)
  }

  const handleEnd = () => {
    setIsDragging(false)
    // Return to center
    setPosition({ x: 0, y: 0 })
    onUpdate(0, 0)
  }

  // Mouse events
  const handleMouseDown = (e: React.MouseEvent) => {
    e.preventDefault()
    handleStart(e.clientX, e.clientY)
  }

  const handleMouseMove = (e: MouseEvent) => {
    handleMove(e.clientX, e.clientY)
  }

  const handleMouseUp = () => {
    handleEnd()
  }

  // Touch events
  const handleTouchStart = (e: React.TouchEvent) => {
    e.preventDefault()
    const touch = e.touches[0]
    handleStart(touch.clientX, touch.clientY)
  }

  const handleTouchMove = (e: TouchEvent) => {
    const touch = e.touches[0]
    handleMove(touch.clientX, touch.clientY)
  }

  const handleTouchEnd = () => {
    handleEnd()
  }

  // Add/remove global event listeners
  useEffect(() => {
    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove)
      window.addEventListener('mouseup', handleMouseUp)
      window.addEventListener('touchmove', handleTouchMove)
      window.addEventListener('touchend', handleTouchEnd)

      return () => {
        window.removeEventListener('mousemove', handleMouseMove)
        window.removeEventListener('mouseup', handleMouseUp)
        window.removeEventListener('touchmove', handleTouchMove)
        window.removeEventListener('touchend', handleTouchEnd)
      }
    }
  }, [isDragging])

  // Calculate stick position in pixels
  const stickX = position.x * maxDistance
  const stickY = -position.y * maxDistance // Invert back for display

  return (
    <div className="flex flex-col items-center gap-3">
      {/* Joystick Container */}
      <div
        ref={containerRef}
        onMouseDown={handleMouseDown}
        onTouchStart={handleTouchStart}
        className={`relative rounded-full bg-gray-800 border-2 ${
          disabled ? 'border-gray-700 opacity-50' : 'border-gray-600'
        } ${isDragging ? 'ring-2 ring-decent-blue' : ''}`}
        style={{ width: size, height: size }}
      >
        {/* Center crosshair */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div className="w-8 h-0.5 bg-gray-700" />
          <div className="absolute w-0.5 h-8 bg-gray-700" />
        </div>

        {/* Quadrant indicators */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none opacity-30">
          <div className="text-xs text-gray-500 absolute top-2">↑ Pressure</div>
          <div className="text-xs text-gray-500 absolute bottom-2">↓</div>
          <div className="text-xs text-gray-500 absolute left-2">← Flow</div>
          <div className="text-xs text-gray-500 absolute right-2">→</div>
        </div>

        {/* Joystick stick */}
        <div
          className={`absolute w-12 h-12 rounded-full ${
            disabled ? 'bg-gray-700' : 'bg-decent-blue'
          } shadow-lg transition-shadow ${
            isDragging ? 'shadow-xl shadow-decent-blue/50' : ''
          } flex items-center justify-center cursor-grab active:cursor-grabbing`}
          style={{
            left: `calc(50% + ${stickX}px)`,
            top: `calc(50% + ${stickY}px)`,
            transform: 'translate(-50%, -50%)',
            touchAction: 'none',
          }}
        >
          <Activity className="w-6 h-6 text-white" />
        </div>
      </div>

      {/* Value display */}
      <div className="flex gap-4 text-sm">
        <div className="flex flex-col items-center">
          <span className="text-gray-400">Flow</span>
          <span className="text-white font-mono font-bold">
            {position.x >= 0 ? '+' : ''}
            {(position.x * 100).toFixed(0)}%
          </span>
        </div>
        <div className="w-px bg-gray-700" />
        <div className="flex flex-col items-center">
          <span className="text-gray-400">Pressure</span>
          <span className="text-white font-mono font-bold">
            {position.y >= 0 ? '+' : ''}
            {(position.y * 100).toFixed(0)}%
          </span>
        </div>
      </div>

      {/* Instructions */}
      <p className="text-xs text-gray-500 text-center max-w-xs">
        Drag to adjust flow (horizontal) and pressure (vertical) in real-time
      </p>
    </div>
  )
}
