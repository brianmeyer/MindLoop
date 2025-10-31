import { cn } from "./ui/utils";

interface MoodChipProps {
  label: string;
  selected?: boolean;
  onClick?: () => void;
  color?: 'calm' | 'stress' | 'joy' | 'sad' | 'anxious' | 'neutral';
}

const moodColors = {
  calm: 'bg-[#7bb8e7]/20 text-[#2563eb] border-[#7bb8e7]/40',
  stress: 'bg-[#f59e0b]/20 text-[#d97706] border-[#f59e0b]/40',
  joy: 'bg-[#6ee7b7]/20 text-[#059669] border-[#6ee7b7]/40',
  sad: 'bg-[#a78bfa]/20 text-[#7c3aed] border-[#a78bfa]/40',
  anxious: 'bg-[#fbbf24]/20 text-[#d97706] border-[#fbbf24]/40',
  neutral: 'bg-[#94a3b8]/20 text-[#475569] border-[#94a3b8]/40',
};

const selectedColors = {
  calm: 'bg-[#7bb8e7] text-white border-[#7bb8e7]',
  stress: 'bg-[#f59e0b] text-white border-[#f59e0b]',
  joy: 'bg-[#6ee7b7] text-[#065f46] border-[#6ee7b7]',
  sad: 'bg-[#a78bfa] text-white border-[#a78bfa]',
  anxious: 'bg-[#fbbf24] text-[#78350f] border-[#fbbf24]',
  neutral: 'bg-[#94a3b8] text-white border-[#94a3b8]',
};

export function MoodChip({ label, selected, onClick, color = 'neutral' }: MoodChipProps) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "px-4 py-2.5 rounded-full border-2 transition-all duration-200 min-h-[48px]",
        selected ? selectedColors[color] : moodColors[color],
        "active:scale-95"
      )}
    >
      {label}
    </button>
  );
}
