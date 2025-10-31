interface ValenceGaugeProps {
  value: number; // -1 to 1, negative is unpleasant, positive is pleasant
  compact?: boolean;
}

export function ValenceGauge({ value, compact = false }: ValenceGaugeProps) {
  const percentage = ((value + 1) / 2) * 100;

  if (compact) {
    return (
      <div className="relative h-2 bg-muted rounded-full overflow-hidden">
        <div 
          className="absolute left-0 top-0 h-full bg-gradient-to-r from-[#a78bfa] via-[#94a3b8] to-[#6ee7b7] rounded-full transition-all"
          style={{ width: `${percentage}%` }}
        />
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <span className="text-muted-foreground">Unpleasant</span>
        <span className="text-muted-foreground">Pleasant</span>
      </div>
      <div className="relative h-3 bg-muted rounded-full overflow-hidden">
        <div 
          className="absolute left-0 top-0 h-full bg-gradient-to-r from-[#a78bfa] via-[#94a3b8] to-[#6ee7b7] rounded-full transition-all"
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
}
