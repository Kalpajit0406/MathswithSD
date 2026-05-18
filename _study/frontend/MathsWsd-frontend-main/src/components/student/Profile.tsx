import { useState } from "react";
import { X } from "lucide-react";

type Student = {
  fullName: string;
  studentMobile: string;
  classNo: number;
  guardianName: string;
  guardianMobile: string;
  verified: boolean;
  language: string;
  createdAt: string;
};

export default function ProfileButton({
  label = "View Profile",
  localStorageKey = "student",
}: {
  label?: string;
  localStorageKey?: string;
}) {
  const [open, setOpen] = useState(false);
  const student: Partial<Student> | null = (() => {
    try {
      const raw = localStorage.getItem(localStorageKey);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  })();

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="rounded-lg bg-slate-900 px-4 py-2 w-full font-semibold text-white shadow hover:bg-slate-800"
      >
        {label}
      </button>

      {open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60" onClick={()=>setOpen(false)}>
          <div className="relative mx-4 w-full max-w-md rounded-2xl border border-slate-700 bg-white text-slate-900 shadow-2xl dark:bg-slate-900 dark:text-slate-100">
            <div className="space-y-2 px-5 py-5">
              {student ? (
                <>
                  <div className="flex items-center justify-between rounded-xl bg-slate-50 p-4 dark:bg-slate-800/60">
                    <p className="text-2xl font-bold">
                      {student.fullName || "NAME NOT FOUND"}
                    </p>
                    <button
                      onClick={() => setOpen(false)}
                      className="rounded-md p-1.5 text-slate-500 hover:bg-slate-100"
                    >
                      <X size={20} />
                    </button>
                  </div>

                  <DisplayRow label="Class" value={String(student.classNo ?? "—")} />
                  <DisplayRow label="Medium" value={student.language || "—"} />
                  <DisplayRow label="Mobile No." value={`+91 ${student.studentMobile}` || "—"} />
                  <DisplayRow label="Guardian" value={student.guardianName || "—"} />
                  <DisplayRow label="Guardian Mobile No." value={`+91 ${student.guardianMobile}` || "—"} />
                  <DisplayRow
                    label="Verified"
                    value={student.verified ? "Yes" : "No"}
                  />
                  <DisplayRow
                    label="Created"
                    value={
                      student.createdAt
                        ? new Date(student.createdAt).toLocaleString()
                        : "—"
                    }
                  />
                </>
              ) : (
                <p className="text-slate-600 dark:text-slate-300">
                  No student profile found.
                </p>
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
}

function DisplayRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-4 rounded-xl border border-slate-200 px-4 py-3 dark:border-slate-800">
      <span className="text-sm text-slate-500 dark:text-slate-400">{label}</span>
      <span className="max-w-[60%] rounded-md px-2 py-1 text-sm font-medium bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-100">
        {value}
      </span>
    </div>
  );
}
