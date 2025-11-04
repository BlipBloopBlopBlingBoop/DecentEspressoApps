import { useState, useEffect } from 'react'
import { useShotStore } from '../stores/shotStore'
import { databaseService } from '../services/databaseService'
import { ShotData } from '../types/decent'
import { Search, Trash2, Star, TrendingUp, Calendar, Filter } from 'lucide-react'
import { formatDateTime, formatDuration, formatRatio } from '../utils/formatters'
import ShotChart from '../components/ShotChart'

export default function HistoryPage() {
  const { shots } = useShotStore()
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedShot, setSelectedShot] = useState<ShotData | null>(null)
  const [ratingFilter, setRatingFilter] = useState<number | null>(null)

  useEffect(() => {
    loadShots()
  }, [])

  const loadShots = async () => {
    const stored = await databaseService.getAllShots()
    useShotStore.getState().loadShots(stored)
  }

  const filteredShots = shots.filter((shot) => {
    if (ratingFilter && shot.rating !== ratingFilter) return false
    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      return (
        shot.profileName.toLowerCase().includes(query) ||
        shot.notes?.toLowerCase().includes(query) ||
        shot.metadata?.coffee?.toLowerCase().includes(query)
      )
    }
    return true
  })

  const handleDelete = async (id: string) => {
    if (confirm('Delete this shot?')) {
      useShotStore.getState().deleteShot(id)
      await databaseService.deleteShot(id)
      if (selectedShot?.id === id) {
        setSelectedShot(null)
      }
    }
  }

  const handleUpdateRating = async (id: string, rating: number) => {
    useShotStore.getState().updateShot(id, { rating })
    const shot = shots.find((s) => s.id === id)
    if (shot) {
      await databaseService.saveShot({ ...shot, rating })
    }
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="bg-gray-800 p-4 space-y-3">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-bold text-white">Shot History</h1>
          <div className="text-sm text-gray-400">{shots.length} shots</div>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input
            type="text"
            placeholder="Search shots..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-decent-blue"
          />
        </div>

        {/* Rating Filter */}
        <div className="flex items-center gap-2">
          <Filter className="w-4 h-4 text-gray-400" />
          <div className="flex gap-2">
            <RatingFilterButton
              active={ratingFilter === null}
              onClick={() => setRatingFilter(null)}
              label="All"
            />
            {[5, 4, 3].map((rating) => (
              <RatingFilterButton
                key={rating}
                active={ratingFilter === rating}
                onClick={() => setRatingFilter(rating)}
                label={`${rating}★`}
              />
            ))}
          </div>
        </div>
      </div>

      {/* Shots List or Detail View */}
      <div className="flex-1 overflow-y-auto">
        {selectedShot ? (
          <ShotDetailView
            shot={selectedShot}
            onBack={() => setSelectedShot(null)}
            onDelete={() => handleDelete(selectedShot.id)}
            onUpdateRating={(rating) => handleUpdateRating(selectedShot.id, rating)}
          />
        ) : (
          <div className="p-4 space-y-3">
            {filteredShots.length === 0 ? (
              <div className="text-center py-12">
                <TrendingUp className="w-16 h-16 text-gray-600 mx-auto mb-4" />
                <p className="text-gray-500">No shots recorded yet</p>
                <p className="text-gray-600 text-sm mt-2">
                  Start brewing to build your shot history
                </p>
              </div>
            ) : (
              filteredShots.map((shot) => (
                <ShotCard
                  key={shot.id}
                  shot={shot}
                  onClick={() => setSelectedShot(shot)}
                />
              ))
            )}
          </div>
        )}
      </div>
    </div>
  )
}

function RatingFilterButton({
  active,
  onClick,
  label,
}: {
  active: boolean
  onClick: () => void
  label: string
}) {
  return (
    <button
      onClick={onClick}
      className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
        active
          ? 'bg-decent-blue text-white'
          : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
      }`}
    >
      {label}
    </button>
  )
}

interface ShotCardProps {
  shot: ShotData
  onClick: () => void
}

function ShotCard({ shot, onClick }: ShotCardProps) {
  return (
    <div
      onClick={onClick}
      className="bg-gray-800 rounded-lg p-4 cursor-pointer hover:bg-gray-750 transition-colors"
    >
      <div className="flex items-start justify-between mb-2">
        <div className="flex-1">
          <h3 className="text-lg font-semibold text-white">{shot.profileName}</h3>
          <p className="text-sm text-gray-400 flex items-center gap-1">
            <Calendar className="w-3 h-3" />
            {formatDateTime(shot.startTime)}
          </p>
        </div>
        {shot.rating && (
          <div className="flex items-center gap-1 text-yellow-500">
            <Star className="w-4 h-4 fill-current" />
            <span className="text-sm font-medium">{shot.rating}</span>
          </div>
        )}
      </div>

      <div className="grid grid-cols-3 gap-3 text-sm">
        <div>
          <div className="text-gray-400">Duration</div>
          <div className="text-white font-medium">{formatDuration(shot.duration)}</div>
        </div>
        {shot.finalWeight && (
          <div>
            <div className="text-gray-400">Yield</div>
            <div className="text-white font-medium">{shot.finalWeight.toFixed(1)}g</div>
          </div>
        )}
        {shot.metadata?.dose && shot.finalWeight && (
          <div>
            <div className="text-gray-400">Ratio</div>
            <div className="text-white font-medium">
              {formatRatio(shot.metadata.dose, shot.finalWeight)}
            </div>
          </div>
        )}
      </div>

      {shot.metadata?.coffee && (
        <div className="mt-2 text-sm text-gray-300">☕ {shot.metadata.coffee}</div>
      )}
    </div>
  )
}

interface ShotDetailViewProps {
  shot: ShotData
  onBack: () => void
  onDelete: () => void
  onUpdateRating: (rating: number) => void
}

function ShotDetailView({ shot, onBack, onDelete, onUpdateRating }: ShotDetailViewProps) {
  const [notes, setNotes] = useState(shot.notes || '')
  const [isEditingNotes, setIsEditingNotes] = useState(false)

  const handleSaveNotes = async () => {
    useShotStore.getState().updateShot(shot.id, { notes })
    await databaseService.saveShot({ ...shot, notes })
    setIsEditingNotes(false)
  }

  return (
    <div className="p-4 space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <button
          onClick={onBack}
          className="text-decent-blue hover:text-blue-400 font-medium"
        >
          ← Back
        </button>
        <button
          onClick={onDelete}
          className="p-2 text-red-500 hover:bg-red-900/20 rounded-lg transition-colors"
        >
          <Trash2 className="w-5 h-5" />
        </button>
      </div>

      {/* Shot Info */}
      <div className="bg-gray-800 rounded-lg p-4 space-y-3">
        <h2 className="text-2xl font-bold text-white">{shot.profileName}</h2>
        <p className="text-gray-400">{formatDateTime(shot.startTime)}</p>

        {/* Rating */}
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-400">Rate this shot:</span>
          <div className="flex gap-1">
            {[1, 2, 3, 4, 5].map((rating) => (
              <button
                key={rating}
                onClick={() => onUpdateRating(rating)}
                className="p-1 hover:scale-110 transition-transform"
              >
                <Star
                  className={`w-5 h-5 ${
                    shot.rating && rating <= shot.rating
                      ? 'fill-yellow-500 text-yellow-500'
                      : 'text-gray-600'
                  }`}
                />
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 gap-3">
        <StatCard label="Duration" value={formatDuration(shot.duration)} />
        {shot.finalWeight && (
          <StatCard label="Yield" value={`${shot.finalWeight.toFixed(1)}g`} />
        )}
        {shot.metadata?.dose && (
          <StatCard label="Dose" value={`${shot.metadata.dose}g`} />
        )}
        {shot.metadata?.dose && shot.finalWeight && (
          <StatCard
            label="Ratio"
            value={formatRatio(shot.metadata.dose, shot.finalWeight)}
          />
        )}
      </div>

      {/* Chart */}
      <div className="bg-gray-800 rounded-lg p-4">
        <h3 className="text-lg font-semibold text-white mb-4">Extraction Profile</h3>
        <ShotChart data={shot.dataPoints} />
      </div>

      {/* Metadata */}
      {shot.metadata && (
        <div className="bg-gray-800 rounded-lg p-4 space-y-2">
          <h3 className="text-lg font-semibold text-white mb-2">Details</h3>
          {shot.metadata.coffee && (
            <InfoRow label="Coffee" value={shot.metadata.coffee} />
          )}
          {shot.metadata.grindSize && (
            <InfoRow label="Grind Size" value={shot.metadata.grindSize} />
          )}
        </div>
      )}

      {/* Notes */}
      <div className="bg-gray-800 rounded-lg p-4">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-lg font-semibold text-white">Notes</h3>
          {!isEditingNotes && (
            <button
              onClick={() => setIsEditingNotes(true)}
              className="text-sm text-decent-blue hover:text-blue-400"
            >
              Edit
            </button>
          )}
        </div>
        {isEditingNotes ? (
          <div className="space-y-2">
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Add notes about this shot..."
              rows={4}
              className="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-decent-blue resize-none"
            />
            <div className="flex gap-2">
              <button
                onClick={handleSaveNotes}
                className="px-4 py-2 bg-decent-blue hover:bg-blue-700 text-white rounded-lg text-sm font-medium transition-colors"
              >
                Save
              </button>
              <button
                onClick={() => {
                  setNotes(shot.notes || '')
                  setIsEditingNotes(false)
                }}
                className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg text-sm font-medium transition-colors"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <p className="text-gray-300">
            {shot.notes || 'No notes for this shot'}
          </p>
        )}
      </div>
    </div>
  )
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-gray-800 rounded-lg p-4">
      <div className="text-sm text-gray-400 mb-1">{label}</div>
      <div className="text-2xl font-bold text-white">{value}</div>
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between py-1">
      <span className="text-gray-400 text-sm">{label}</span>
      <span className="text-white text-sm font-medium">{value}</span>
    </div>
  )
}
