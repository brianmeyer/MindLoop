import { useState } from "react";
import { ArrowLeft } from "lucide-react";
import { ProgressDots } from "../ProgressDots";
import { Textarea } from "../ui/textarea";
import { Button } from "../ui/button";

interface GuidedDeeperProps {
  onBack: () => void;
  onComplete: (responses: string[]) => void;
}

const questions = [
  "If your best friend felt this way, what would you want them to know?",
  "What's one small thing in your control before tomorrow?",
];

export function GuidedDeeper({ onBack, onComplete }: GuidedDeeperProps) {
  const [currentQuestion, setCurrentQuestion] = useState(0);
  const [responses, setResponses] = useState<string[]>(["", ""]);

  const handleResponseChange = (value: string) => {
    const newResponses = [...responses];
    newResponses[currentQuestion] = value;
    setResponses(newResponses);
  };

  const handleNext = () => {
    if (currentQuestion < questions.length - 1) {
      setCurrentQuestion(currentQuestion + 1);
    } else {
      onComplete(responses);
    }
  };

  const handleSaveForLater = () => {
    onBack();
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
        <ProgressDots current={currentQuestion + 1} total={questions.length} />
        <div className="w-10" />
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col p-5 justify-between">
        <div className="pt-8 space-y-8 max-w-md mx-auto w-full">
          {/* Question */}
          <div className="bg-card border border-border rounded-[20px] p-6 space-y-4">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-full bg-primary text-primary-foreground flex items-center justify-center shrink-0">
                {currentQuestion + 1}
              </div>
              <h2 className="text-foreground flex-1">{questions[currentQuestion]}</h2>
            </div>
          </div>

          {/* Response */}
          <div className="space-y-3">
            <label className="text-muted-foreground">Your thoughts</label>
            <Textarea
              value={responses[currentQuestion]}
              onChange={(e) => handleResponseChange(e.target.value)}
              placeholder="Take your time..."
              className="min-h-[200px] resize-none rounded-[20px] bg-muted border-0"
            />
          </div>
        </div>

        {/* Actions */}
        <div className="space-y-3 max-w-md mx-auto w-full">
          <Button
            onClick={handleNext}
            size="lg"
            className="w-full min-h-[56px] rounded-[20px]"
            disabled={!responses[currentQuestion].trim()}
          >
            {currentQuestion < questions.length - 1 ? "Next" : "Finish"}
          </Button>

          <button
            onClick={handleSaveForLater}
            className="w-full py-3 text-muted-foreground active:scale-95 transition-transform"
          >
            Save for later
          </button>
        </div>
      </div>
    </div>
  );
}
