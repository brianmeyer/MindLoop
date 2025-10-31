import { Mic, Pause, Square } from "lucide-react";
import { cn } from "./ui/utils";

interface VoiceMicButtonProps {
  state: 'idle' | 'listening' | 'paused';
  onToggle: () => void;
  onStop?: () => void;
}

export function VoiceMicButton({ state, onToggle, onStop }: VoiceMicButtonProps) {
  if (state === 'listening') {
    return (
      <div className="flex items-center gap-4">
        {/* Main mic button - acts as stop when recording */}
        <button
          onClick={onStop}
          className="w-20 h-20 rounded-full bg-[#7bb8e7] text-white flex items-center justify-center shadow-lg animate-pulse active:scale-95 transition-transform"
          aria-label="Stop recording"
        >
          <Square className="w-9 h-9 fill-current" />
        </button>
        {/* Smaller pause button */}
        <button
          onClick={onToggle}
          className="w-12 h-12 rounded-full bg-muted text-foreground flex items-center justify-center shadow active:scale-95 transition-transform"
          aria-label="Pause recording"
        >
          <Pause className="w-5 h-5" />
        </button>
      </div>
    );
  }

  if (state === 'paused') {
    return (
      <div className="flex items-center gap-4">
        {/* Main mic button - resume recording */}
        <button
          onClick={onToggle}
          className="w-20 h-20 rounded-full bg-muted text-foreground flex items-center justify-center shadow-lg active:scale-95 transition-transform"
          aria-label="Resume recording"
        >
          <Mic className="w-10 h-10" />
        </button>
        {/* Stop button when paused */}
        {onStop && (
          <button
            onClick={onStop}
            className="w-12 h-12 rounded-full bg-destructive/10 text-destructive flex items-center justify-center shadow active:scale-95 transition-transform"
            aria-label="Stop recording"
          >
            <Square className="w-5 h-5 fill-current" />
          </button>
        )}
      </div>
    );
  }

  // Idle state - initial mic button
  return (
    <button
      onClick={onToggle}
      className="w-20 h-20 rounded-full bg-primary text-primary-foreground flex items-center justify-center shadow-lg active:scale-95 transition-transform"
      aria-label="Start recording"
    >
      <Mic className="w-10 h-10" />
    </button>
  );
}
