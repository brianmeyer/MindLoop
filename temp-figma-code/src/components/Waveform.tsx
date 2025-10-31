interface WaveformProps {
  isActive: boolean;
}

export function Waveform({ isActive }: WaveformProps) {
  const barCount = 40;
  
  return (
    <div className="w-full max-w-md mx-auto h-24 bg-muted rounded-[16px] p-4 flex items-center justify-center gap-[2px]">
      {Array.from({ length: barCount }).map((_, i) => (
        <div
          key={i}
          className="flex-1 bg-[#7bb8e7] rounded-full min-w-[2px] transition-[height,opacity] duration-300 ease-in-out"
          style={{
            height: isActive ? '100%' : '20%',
            opacity: isActive ? 0.7 : 0.3,
            animationName: isActive ? 'waveform' : 'none',
            animationDuration: `${600 + (i % 8) * 50}ms`,
            animationTimingFunction: 'ease-in-out',
            animationIterationCount: 'infinite',
            animationDirection: 'alternate',
            animationDelay: `${i * 15}ms`,
          }}
        />
      ))}
    </div>
  );
}
