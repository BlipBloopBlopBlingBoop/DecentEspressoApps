import React from 'react'
import { motion } from 'framer-motion'

interface GradientButtonProps {
  children: React.ReactNode
  onClick?: () => void
  variant?: 'espresso' | 'steam' | 'primary' | 'danger'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  className?: string
  icon?: React.ReactNode
}

export const GradientButton: React.FC<GradientButtonProps> = ({
  children,
  onClick,
  variant = 'primary',
  size = 'md',
  disabled = false,
  className = '',
  icon
}) => {
  const variantClasses = {
    espresso: 'bg-gradient-espresso hover:shadow-lg hover:shadow-coffee/50',
    steam: 'bg-gradient-steam hover:shadow-lg hover:shadow-purple-500/50',
    primary: 'bg-gradient-to-r from-blue-600 to-blue-800 hover:shadow-lg hover:shadow-blue-500/50',
    danger: 'bg-gradient-to-r from-red-600 to-red-800 hover:shadow-lg hover:shadow-red-500/50'
  }

  const sizeClasses = {
    sm: 'px-4 py-2 text-sm',
    md: 'px-6 py-3 text-base',
    lg: 'px-8 py-4 text-lg'
  }

  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      whileHover={{ scale: 1.05 }}
      onClick={onClick}
      disabled={disabled}
      className={`
        ${variantClasses[variant]}
        ${sizeClasses[size]}
        text-white font-semibold rounded-xl
        transition-all duration-300
        flex items-center justify-center gap-2
        disabled:opacity-50 disabled:cursor-not-allowed
        shadow-md
        ${className}
      `}
    >
      {icon && <span>{icon}</span>}
      {children}
    </motion.button>
  )
}

export default GradientButton
