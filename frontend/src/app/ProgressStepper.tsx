"use client";

interface ProgressStepperProps {
  steps: string[];
  currentStep: number;
}

export default function ProgressStepper({ steps, currentStep }: ProgressStepperProps) {
  return (
    <div className="flex items-center w-full mb-12">
      {steps.map((label, index) => {
        const stepNumber = index + 1;
        const isCompleted = currentStep > stepNumber;
        const isActive = currentStep === stepNumber;

        return (
          <>
            <div className="flex flex-col items-center">
              <div
                className={`w-10 h-10 rounded-full flex items-center justify-center transition-all duration-300
                  ${isCompleted ? "bg-[var(--accent-primary)] text-white" : ""}
                  ${isActive ? "border-2 border-[var(--accent-primary)] text-[var(--accent-primary)]" : ""}
                  ${!isCompleted && !isActive ? "border border-[var(--border-color)] text-[var(--text-muted)]" : ""}
                `}
              >
                {isCompleted ? (
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                ) : (
                  <span className="font-bold">{stepNumber}</span>
                )}
              </div>
              <p className={`mt-2 text-xs text-center ${isActive ? "text-[var(--text-primary)]" : "text-[var(--text-muted)]"}`}>{label}</p>
            </div>
            {index < steps.length - 1 && (
              <div
                className={`flex-1 h-1 mx-2 transition-colors duration-300
                  ${currentStep > stepNumber ? "bg-[var(--accent-primary)]" : "bg-[var(--border-color)]"}
                `}
              />
            )}
          </>
        );
      })}
    </div>
  );
}