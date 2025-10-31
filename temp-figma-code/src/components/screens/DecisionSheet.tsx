import { ArrowLeft } from "lucide-react";
import { DecisionCard } from "../DecisionCard";

interface DecisionSheetProps {
  onBack: () => void;
  onGoDeeper: () => void;
  onQuickPractice: () => void;
  onSaveForLater: () => void;
}

export function DecisionSheet({ onBack, onGoDeeper, onQuickPractice, onSaveForLater }: DecisionSheetProps) {
  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <div className="p-5 flex items-center border-b border-border">
        <button
          onClick={onBack}
          className="w-10 h-10 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
      </div>

      {/* Main Content */}
      <div className="flex-1 p-5 space-y-6">
        <div className="pt-4">
          <h2 className="text-center text-foreground">Here's what could help most in the time you have</h2>
        </div>

        <div className="space-y-4 max-w-md mx-auto">
          {/* Primary option */}
          <DecisionCard
            title="Do a quick practice"
            description="90-second reset to shift your state"
            badge="90s"
            onClick={onQuickPractice}
            variant="primary"
          />

          {/* Secondary options */}
          <DecisionCard
            title="Go deeper now"
            description="Explore what's underneath • 2–3 min"
            onClick={onGoDeeper}
          />

          <DecisionCard
            title="Save deeper for later"
            description="Schedule time when you're ready"
            onClick={onSaveForLater}
          />
        </div>
      </div>
    </div>
  );
}
