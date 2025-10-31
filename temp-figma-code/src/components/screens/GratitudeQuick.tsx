import { useState } from "react";
import { ArrowLeft, Heart, Keyboard } from "lucide-react";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import { VoiceMicButton } from "../VoiceMicButton";

interface GratitudeQuickProps {
  onBack: () => void;
  onSave: (gratitudes: string[]) => void;
}

export function GratitudeQuick({ onBack, onSave }: GratitudeQuickProps) {
  const [gratitudes, setGratitudes] = useState(["", "", ""]);
  const [currentIndex, setCurrentIndex] = useState<number | null>(null);
  const [micState, setMicState] = useState<'idle' | 'listening' | 'paused'>('idle');
  const [inputMode, setInputMode] = useState<'voice' | 'text'>('voice');

  const handleChange = (index: number, value: string) => {
    const newGratitudes = [...gratitudes];
    newGratitudes[index] = value;
    setGratitudes(newGratitudes);
  };

  const handleToggleMic = () => {
    if (micState === 'idle' && currentIndex === null) {
      // Start recording for first empty slot
      const firstEmpty = gratitudes.findIndex(g => !g.trim());
      if (firstEmpty !== -1) {
        setCurrentIndex(firstEmpty);
        setMicState('listening');
      }
    } else if (micState === 'listening') {
      setMicState('paused');
    } else {
      setMicState('listening');
    }
  };

  const handleStopRecording = () => {
    setMicState('idle');
    // Move to next empty slot
    if (currentIndex !== null) {
      const nextEmpty = gratitudes.findIndex((g, i) => i > currentIndex && !g.trim());
      if (nextEmpty !== -1) {
        setCurrentIndex(nextEmpty);
        setMicState('listening');
      } else {
        setCurrentIndex(null);
      }
    }
  };

  const handleSave = () => {
    const filtered = gratitudes.filter(g => g.trim());
    if (filtered.length > 0) {
      onSave(filtered);
    }
  };

  const canSave = gratitudes.some(g => g.trim());

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
        <button
          onClick={() => setInputMode(inputMode === 'voice' ? 'text' : 'voice')}
          className="w-10 h-10 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
        >
          <Keyboard className="w-5 h-5" />
        </button>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col p-5 justify-between">
        <div className="pt-8 space-y-8 max-w-md mx-auto w-full">
          {/* Title */}
          <div className="text-center space-y-2">
            <div className="inline-flex items-center justify-center w-14 h-14 rounded-full bg-[#6ee7b7]/20 mb-2">
              <Heart className="w-7 h-7 text-[#059669]" />
            </div>
            <h2 className="text-foreground">Name 1–3 specific things that mattered today</h2>
          </div>

          {inputMode === 'voice' ? (
            /* Voice Input Mode */
            <>
              {/* Current Recording Indicator */}
              {currentIndex !== null && micState !== 'idle' && (
                <div className="text-center space-y-2">
                  <p className="text-muted-foreground">
                    {currentIndex === 0 ? "I'm grateful for..." : `And... (${currentIndex + 1}/3)`}
                  </p>
                  <div className="p-4 rounded-[20px] bg-muted min-h-[80px] flex items-center justify-center">
                    <p className="text-foreground">
                      {gratitudes[currentIndex] || "Listening..."}
                    </p>
                  </div>
                </div>
              )}

              {/* Gratitude List */}
              <div className="space-y-3">
                {gratitudes.map((gratitude, index) => (
                  gratitude && (
                    <div
                      key={index}
                      className="p-4 rounded-[20px] bg-[#6ee7b7]/10 border border-[#6ee7b7]/30"
                    >
                      <p className="text-muted-foreground">{index + 1}.</p>
                      <p className="text-foreground">{gratitude}</p>
                    </div>
                  )
                ))}
              </div>

              {/* Voice Button */}
              <div className="flex justify-center pt-4">
                <VoiceMicButton
                  state={micState}
                  onToggle={handleToggleMic}
                  onStop={handleStopRecording}
                />
              </div>
            </>
          ) : (
            /* Text Input Mode */
            <div className="space-y-4">
              {gratitudes.map((gratitude, index) => (
                <div key={index} className="space-y-2">
                  <label className="text-muted-foreground">
                    {index === 0 ? "I'm grateful for..." : `And...`}
                  </label>
                  <Input
                    value={gratitude}
                    onChange={(e) => handleChange(index, e.target.value)}
                    placeholder="Something specific"
                    className="h-14 rounded-[20px] bg-muted border-0"
                  />
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Actions */}
        <div className="max-w-md mx-auto w-full">
          <Button
            onClick={handleSave}
            size="lg"
            className="w-full min-h-[56px] rounded-[20px]"
            disabled={!canSave}
          >
            Save
          </Button>
        </div>
      </div>
    </div>
  );
}
