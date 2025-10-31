import { useState, useEffect } from "react";
import { ArrowLeft, Pause, Play, ThumbsDown } from "lucide-react";
import { ProgressDots } from "../ProgressDots";
import { Button } from "../ui/button";

interface ExercisePlayerProps {
  onBack: () => void;
  onComplete: (helpful: boolean) => void;
  duration?: number; // in seconds, default 90
}

const exerciseSteps = [
  {
    title: "Find your breath",
    instruction: "Close your eyes and notice where you feel your breath most clearly. Chest, belly, or nose.",
  },
  {
    title: "Count slowly",
    instruction: "Breathe in for 4 counts, hold for 4, out for 6. Just three rounds.",
  },
  {
    title: "Notice the shift",
    instruction: "Open your eyes. What's different in your body right now?",
  },
];

export function ExercisePlayer({ onBack, onComplete, duration = 90 }: ExercisePlayerProps) {
  const [currentStep, setCurrentStep] = useState(0);
  const [isPlaying, setIsPlaying] = useState(true);
  const [secondsRemaining, setSecondsRemaining] = useState(duration);

  useEffect(() => {
    if (!isPlaying) return;

    const interval = setInterval(() => {
      setSecondsRemaining((s) => {
        if (s <= 1) {
          clearInterval(interval);
          return 0;
        }
        return s - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [isPlaying]);

  const handleNext = () => {
    if (currentStep < exerciseSteps.length - 1) {
      setCurrentStep(currentStep + 1);
    }
  };

  const handleDone = () => {
    onComplete(true);
  };

  const handleDidntHelp = () => {
    onComplete(false);
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <div className="p-5 flex items-center justify-between border-b border-border">
        <button
          onClick={onBack}
          className="w-10 h-10 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div className="flex items-center gap-2">
          <span className="text-muted-foreground">{Math.floor(secondsRemaining / 60)}:{(secondsRemaining % 60).toString().padStart(2, '0')}</span>
        </div>
        <div className="w-10" />
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col p-5 justify-between">
        <div className="pt-8 space-y-8">
          {/* Title */}
          <div className="text-center space-y-2">
            <h2 className="text-foreground">Quick breathing reset</h2>
            <p className="text-muted-foreground">Helps calm your nervous system</p>
          </div>

          {/* Progress */}
          <div className="flex justify-center">
            <ProgressDots current={currentStep + 1} total={exerciseSteps.length} />
          </div>

          {/* Current Step */}
          <div className="max-w-md mx-auto space-y-6 text-center">
            <h3 className="text-foreground">{exerciseSteps[currentStep].title}</h3>
            <p className="text-muted-foreground leading-relaxed">
              {exerciseSteps[currentStep].instruction}
            </p>
          </div>
        </div>

        {/* Controls */}
        <div className="space-y-4 max-w-md mx-auto w-full">
          <div className="flex items-center justify-center gap-4">
            <button
              onClick={() => setIsPlaying(!isPlaying)}
              className="w-14 h-14 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
            >
              {isPlaying ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6 ml-1" />}
            </button>
          </div>

          {currentStep < exerciseSteps.length - 1 ? (
            <Button
              onClick={handleNext}
              size="lg"
              className="w-full min-h-[56px] rounded-[20px]"
            >
              Next
            </Button>
          ) : (
            <Button
              onClick={handleDone}
              size="lg"
              className="w-full min-h-[56px] rounded-[20px]"
            >
              Done
            </Button>
          )}

          <button
            onClick={handleDidntHelp}
            className="w-full flex items-center justify-center gap-2 text-muted-foreground py-3 active:scale-95 transition-transform"
          >
            <ThumbsDown className="w-4 h-4" />
            <span>This didn't help</span>
          </button>
        </div>
      </div>
    </div>
  );
}
