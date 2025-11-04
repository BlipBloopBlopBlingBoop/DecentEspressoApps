import React from 'react'
import { motion } from 'framer-motion'

interface GlassCardProps {
  children: React.ReactNode
  className?: string
  animate?: boolean
  glowOnHover?: boolean
}

export const GlassCard: React.FC<GlassCardProps> = ({
  children,
  className = '',
  animate = true,
  glowOnHover = false
}) => {
  const Component = animate ? motion.div : 'div'
  const animationProps = animate ? {
    initial: { opacity: 0, y: 20 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.5 },
    whileHover: glowOnHover ? { scale: 1.02 } : undefined
  } : {}

  return (
    <Component
      {...animationProps}
      className={`
        backdrop-blur-xl bg-white/10
        border border-white/20
        rounded-2xl p-6
        shadow-glass
        ${glowOnHover ? 'hover:shadow-glow transition-all duration-300' : ''}
        ${className}
      `}
    >
      {children}
    </Component>
  )
}

export default GlassCard
