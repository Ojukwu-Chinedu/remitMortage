import dynamic from "next/dynamic";

const Navbar = dynamic(() => import("../../components/Navbar"), { ssr: false });

export default function DashboardPage() {
  return (
    <main>
      <Navbar />
      <section className="pt-32 pb-24 px-6">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-4xl font-bold mb-4">Borrower Dashboard</h1>
          <p className="text-[var(--text-secondary)]">
            Welcome! Your onboarding is complete. Your dashboard is under construction.
          </p>
        </div>
      </section>
    </main>
  );
}