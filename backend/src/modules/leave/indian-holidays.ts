/** Common Indian national / gazetted holidays (fixed + typical observances). */
export function indianHolidaysForYear(
  year: number,
): { date: string; name: string }[] {
  const fixed = [
    { m: 1, d: 26, name: 'Republic Day' },
    { m: 5, d: 1, name: 'Labour Day' },
    { m: 8, d: 15, name: 'Independence Day' },
    { m: 10, d: 2, name: 'Gandhi Jayanti' },
    { m: 12, d: 25, name: 'Christmas' },
  ];

  // Approximate / commonly observed movable dates by year (MVP seed).
  const movable: Record<number, { m: number; d: number; name: string }[]> = {
    2025: [
      { m: 3, d: 14, name: 'Holi' },
      { m: 3, d: 31, name: 'Eid ul-Fitr' },
      { m: 4, d: 10, name: 'Mahavir Jayanti' },
      { m: 4, d: 18, name: 'Good Friday' },
      { m: 6, d: 7, name: 'Eid ul-Adha' },
      { m: 8, d: 16, name: 'Janmashtami' },
      { m: 10, d: 2, name: 'Dussehra' },
      { m: 10, d: 20, name: 'Diwali' },
      { m: 11, d: 5, name: 'Guru Nanak Jayanti' },
    ],
    2026: [
      { m: 3, d: 3, name: 'Holi' },
      { m: 3, d: 21, name: 'Eid ul-Fitr' },
      { m: 3, d: 31, name: 'Mahavir Jayanti' },
      { m: 4, d: 3, name: 'Good Friday' },
      { m: 5, d: 28, name: 'Eid ul-Adha' },
      { m: 9, d: 4, name: 'Janmashtami' },
      { m: 10, d: 20, name: 'Dussehra' },
      { m: 11, d: 8, name: 'Diwali' },
      { m: 11, d: 24, name: 'Guru Nanak Jayanti' },
    ],
    2027: [
      { m: 3, d: 22, name: 'Holi' },
      { m: 3, d: 10, name: 'Eid ul-Fitr' },
      { m: 4, d: 19, name: 'Mahavir Jayanti' },
      { m: 3, d: 26, name: 'Good Friday' },
      { m: 5, d: 17, name: 'Eid ul-Adha' },
      { m: 8, d: 25, name: 'Janmashtami' },
      { m: 10, d: 9, name: 'Dussehra' },
      { m: 10, d: 29, name: 'Diwali' },
      { m: 11, d: 14, name: 'Guru Nanak Jayanti' },
    ],
  };

  const rows = [
    ...fixed,
    ...(movable[year] ?? []),
  ].map((h) => ({
    date: `${year}-${String(h.m).padStart(2, '0')}-${String(h.d).padStart(2, '0')}`,
    name: h.name,
  }));

  // De-dupe by date+name
  const seen = new Set<string>();
  return rows.filter((r) => {
    const k = `${r.date}|${r.name}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}
