interface ArousalBarProps {
  value: number; // 0 to 1, 0 is low energy, 1 is high energy
  compact?: boolean;
}

export function ArousalBar({ value, compact = false }: ArousalBarProps) {
  const percentage = value * 100;

  if (compact) {
    return (
      <div className="relative h-2 bg-muted rounded-full overflow-hidden">
        <div 
          className="absolute left-0 top-0 h-full bg-[#7bb8e7] rounded-full transition-all"
          style={{ width: `${percentage}%` }}
        />
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <span className="text-muted-foreground">Low energy</span>
        <span className="text-muted-foreground">High energy</span>
      </div>
      <div className="relative h-3 bg-muted rounded-full overflow-hidden">
        <div 
          className="absolute left-0 top-0 h-full bg-[#7bb8e7] rounded-full transition-all"
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
}
