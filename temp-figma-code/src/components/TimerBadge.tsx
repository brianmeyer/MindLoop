import { Clock } from "lucide-react";

interface TimerBadgeProps {
  seconds: number;
}

export function TimerBadge({ seconds }: TimerBadgeProps) {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  const display = `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;

  return (
    <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-muted">
      <Clock className="w-3.5 h-3.5 text-muted-foreground" />
      <span className="text-muted-foreground">{display}</span>
    </div>
  );
}
