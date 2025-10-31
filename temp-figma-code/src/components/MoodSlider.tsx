import { useState } from "react";
import * as SliderPrimitive from "@radix-ui/react-slider@1.2.3";

interface MoodSliderProps {
  value?: number;
  onChange?: (value: number) => void;
  label?: string;
}

export function MoodSlider({ value, onChange, label }: MoodSliderProps) {
  const [internalValue, setInternalValue] = useState(value ?? 50);
  
  const currentValue = value ?? internalValue;

  const handleChange = (values: number[]) => {
    const newValue = values[0];
    setInternalValue(newValue);
    onChange?.(newValue);
  };

  // Map slider value to mood color
  const getMoodColor = (val: number) => {
    if (val < 25) return "#f59e0b"; // stress/amber
    if (val < 50) return "#fbbf24"; // anxious/yellow
    if (val < 75) return "#94a3b8"; // neutral
    return "#6ee7b7"; // joy/green
  };

  const getMoodLabel = (val: number) => {
    if (val < 25) return "Stressed";
    if (val < 50) return "A bit tense";
    if (val < 75) return "Okay";
    return "Feeling good";
  };

  return (
    <div className="space-y-3 w-full">
      {label && (
        <p className="text-center text-muted-foreground">{label}</p>
      )}
      <div className="px-4">
        {/* Emoji indicators */}
        <div className="flex items-center justify-between mb-6">
          <span className="text-4xl">😰</span>
          <span className="text-4xl">😊</span>
        </div>

        {/* Custom Slider */}
        <SliderPrimitive.Root
          value={[currentValue]}
          onValueChange={handleChange}
          max={100}
          step={1}
          className="relative flex w-full touch-none items-center select-none py-4"
        >
          <SliderPrimitive.Track className="bg-muted relative h-3 w-full grow overflow-hidden rounded-full">
            <SliderPrimitive.Range
              className="absolute h-full transition-colors"
              style={{ backgroundColor: getMoodColor(currentValue) }}
            />
          </SliderPrimitive.Track>
          <SliderPrimitive.Thumb
            className="block size-8 shrink-0 rounded-full border-2 bg-background shadow-lg transition-transform hover:scale-110 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/50 active:scale-95"
            style={{ borderColor: getMoodColor(currentValue) }}
          />
        </SliderPrimitive.Root>

        {/* Text feedback */}
        <div className="text-center mt-4">
          <span 
            className="inline-block px-4 py-1.5 rounded-full transition-colors"
            style={{ 
              backgroundColor: `${getMoodColor(currentValue)}20`,
              color: getMoodColor(currentValue)
            }}
          >
            {getMoodLabel(currentValue)}
          </span>
        </div>
      </div>
    </div>
  );
}
