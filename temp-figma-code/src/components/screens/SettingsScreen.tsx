import { ArrowLeft, Download } from "lucide-react";
import { Button } from "../ui/button";
import { Switch } from "../ui/switch";
import { Label } from "../ui/label";

interface SettingsScreenProps {
  onBack: () => void;
}

export function SettingsScreen({ onBack }: SettingsScreenProps) {
  const tones = [
    { id: 'friend', label: 'Friend', description: 'Warm and conversational' },
    { id: 'coach', label: 'Coach', description: 'Supportive and action-oriented' },
    { id: 'sage', label: 'Sage', description: 'Reflective and philosophical' },
  ];

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
        <h2 className="flex-1 text-center text-foreground">Settings</h2>
        <div className="w-10" />
      </div>

      {/* Main Content */}
      <div className="flex-1 p-5 space-y-8 max-w-md mx-auto w-full">
        {/* Tone */}
        <div className="space-y-4">
          <h3 className="text-foreground">Conversation tone</h3>
          <div className="space-y-2">
            {tones.map((tone) => (
              <button
                key={tone.id}
                className="w-full text-left p-4 rounded-[20px] border border-border hover:border-primary/20 transition-colors active:scale-[0.98]"
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-foreground">{tone.label}</p>
                    <p className="text-muted-foreground">{tone.description}</p>
                  </div>
                  <div className="w-5 h-5 rounded-full border-2 border-primary" />
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Time Budget */}
        <div className="space-y-4">
          <h3 className="text-foreground">Default time budget</h3>
          <div className="flex gap-2">
            {['2 min', '5 min', '10 min'].map((time) => (
              <button
                key={time}
                className="flex-1 py-3 rounded-[20px] border border-border hover:border-primary/20 transition-colors active:scale-95"
              >
                {time}
              </button>
            ))}
          </div>
        </div>

        {/* Toggles */}
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <Label>Voice input</Label>
              <p className="text-muted-foreground">Enable microphone</p>
            </div>
            <Switch defaultChecked />
          </div>

          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <Label>Daily reminders</Label>
              <p className="text-muted-foreground">Evening check-in</p>
            </div>
            <Switch />
          </div>

          <div className="flex items-center justify-between">
            <div className="space-y-1">
              <Label>Cloud sync</Label>
              <p className="text-muted-foreground">Optional backup</p>
            </div>
            <Switch />
          </div>
        </div>

        {/* Privacy */}
        <div className="space-y-4">
          <h3 className="text-foreground">Privacy</h3>
          <div className="p-4 rounded-[20px] bg-muted space-y-2">
            <p className="text-foreground">All processing happens on your device</p>
            <p className="text-muted-foreground">
              Your thoughts, emotions, and insights never leave your phone unless you choose to sync.
            </p>
          </div>
        </div>

        {/* Export Data */}
        <Button variant="outline" size="lg" className="w-full rounded-[20px] min-h-[56px]">
          <Download className="w-5 h-5 mr-2" />
          Export my data
        </Button>
      </div>
    </div>
  );
}
