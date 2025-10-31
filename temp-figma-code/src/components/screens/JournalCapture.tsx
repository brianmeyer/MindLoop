import { useState, useEffect } from "react";
import { ArrowLeft } from "lucide-react";
import { VoiceMicButton } from "../VoiceMicButton";
import { TimerBadge } from "../TimerBadge";
import { Waveform } from "../Waveform";
import { Textarea } from "../ui/textarea";

interface JournalCaptureProps {
  onBack: () => void;
  onComplete: (transcript: string) => void;
}

export function JournalCapture({ onBack, onComplete }: JournalCaptureProps) {
  const [micState, setMicState] = useState<'idle' | 'listening' | 'paused'>('idle');
  const [transcript, setTranscript] = useState('');
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (micState === 'listening') {
      interval = setInterval(() => {
        setSeconds(s => s + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [micState]);

  const handleToggleMic = () => {
    console.log('handleToggleMic called', { micState });
    if (micState === 'idle') {
      setMicState('listening');
    } else if (micState === 'listening') {
      setMicState('paused');
    } else {
      setMicState('listening');
    }
  };

  const handleStop = () => {
    console.log('handleStop called', { transcript, seconds, micState });
    setMicState('idle');
    if (transcript.trim() || seconds > 0) {
      console.log('Calling onComplete');
      onComplete(transcript);
    } else {
      console.log('Condition not met - not calling onComplete');
    }
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
        <TimerBadge seconds={seconds} />
        <div className="w-10" />
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col p-5 space-y-8">
        {/* Prompt */}
        <div className="text-center pt-8">
          <h2 className="text-foreground">What's on your mind?</h2>
        </div>

        {/* Voice Button */}
        <div className="flex-1 flex items-center justify-center">
          <VoiceMicButton
            state={micState}
            onToggle={handleToggleMic}
            onStop={handleStop}
          />
        </div>

        {/* Waveform */}
        {micState !== 'idle' && (
          <div className="space-y-4">
            <Waveform isActive={micState === 'listening'} />
          </div>
        )}

        {/* Live Transcript */}
        {micState !== 'idle' && (
          <div className="space-y-4">
            <Textarea
              value={transcript}
              onChange={(e) => setTranscript(e.target.value)}
              placeholder="Your thoughts appear here..."
              className="min-h-[120px] resize-none rounded-[20px] bg-muted border-0"
            />
          </div>
        )}
      </div>
    </div>
  );
}
