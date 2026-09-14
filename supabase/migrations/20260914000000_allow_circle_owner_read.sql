-- INSERT ... RETURNING evaluates the Circle read policy before the AFTER INSERT
-- trigger has added the owner's circle_members row. Let owners read their own
-- Circle directly so creation can return the inserted record.
drop policy circles_member_read on public.circles;
create policy circles_member_read on public.circles for select to authenticated
using (auth.uid() = owner_id or private.is_circle_member(id));
