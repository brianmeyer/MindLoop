import { X } from "lucide-react";
import { ValenceGauge } from "../ValenceGauge";
import { ArousalBar } from "../ArousalBar";
import { Badge } from "../ui/badge";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "../ui/sheet";

interface SignalsSummaryProps {
  open: boolean;
  onClose: () => void;
}

export function SignalsSummary({ open, onClose }: SignalsSummaryProps) {
  const valence = 0.3; // Slightly pleasant
  const arousal = 0.7; // High energy
  const labels = ["Stressed", "Focused", "Determined"];
  const topics = ["Work", "Presentation", "Preparation"];

  return (
    <Sheet open={open} onOpenChange={onClose}>
      <SheetContent side="bottom" className="rounded-t-[20px]">
        <SheetHeader>
          <SheetTitle>What we picked up</SheetTitle>
          <SheetDescription>
            Analysis of your emotional state and topics from your journal entry
          </SheetDescription>
        </SheetHeader>
        <div className="space-y-6 py-6">
          {/* Valence */}
          <div>
            <h4 className="mb-3 text-foreground">Emotional tone</h4>
            <ValenceGauge value={valence} />
          </div>

          {/* Arousal */}
          <div>
            <h4 className="mb-3 text-foreground">Energy level</h4>
            <ArousalBar value={arousal} />
          </div>

          {/* Labels */}
          <div className="space-y-3">
            <h4 className="text-foreground">Detected emotions</h4>
            <div className="flex flex-wrap gap-2">
              {labels.map((label, i) => (
                <Badge key={i} variant="secondary" className="rounded-full">
                  {label}
                </Badge>
              ))}
            </div>
          </div>

          {/* Topics */}
          <div className="space-y-3">
            <h4 className="text-foreground">Topics</h4>
            <div className="flex flex-wrap gap-2">
              {topics.map((topic, i) => (
                <Badge key={i} variant="outline" className="rounded-full">
                  {topic}
                </Badge>
              ))}
            </div>
          </div>

          {/* Confidence note */}
          <p className="text-muted-foreground text-center">
            This analysis stays private on your device
          </p>
        </div>
      </SheetContent>
    </Sheet>
  );
}
