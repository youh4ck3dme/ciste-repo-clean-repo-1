import type { SupabaseClient } from '@supabase/supabase-js'

type FavoriteRow = {
  id: string
  client_id: string
  service_id: string
}

export async function addFavorite(
  supabase: SupabaseClient,
  userId: string,
  serviceId: string,
): Promise<FavoriteRow> {
  // 3) insert flow: user must have client_profiles row first
  const { data: clientProfile, error: clientError } = await supabase
    .from('client_profiles')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()

  if (clientError) throw clientError
  if (!clientProfile) {
    throw new Error('Client profile is required before adding favorites')
  }

  const { data, error } = await supabase
    .from('favorite_services')
    .insert({ client_id: clientProfile.id, service_id: serviceId })
    .select('id, client_id, service_id')
    .single()

  if (error) throw error
  return data as FavoriteRow
}

export async function deleteFavorite(
  supabase: SupabaseClient,
  userId: string,
  serviceId: string,
): Promise<void> {
  const { data: clientProfile, error: clientError } = await supabase
    .from('client_profiles')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()

  if (clientError) throw clientError
  if (!clientProfile) return

  const { error } = await supabase
    .from('favorite_services')
    .delete()
    .eq('client_id', clientProfile.id)
    .eq('service_id', serviceId)

  if (error) throw error
}

export async function listFavorites(
  supabase: SupabaseClient,
  userId: string,
): Promise<FavoriteRow[]> {
  const { data: clientProfile, error: clientError } = await supabase
    .from('client_profiles')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()

  if (clientError) throw clientError
  if (!clientProfile) return []

  const { data, error } = await supabase
    .from('favorite_services')
    .select('id, client_id, service_id')
    .eq('client_id', clientProfile.id)

  if (error) throw error
  return (data ?? []) as FavoriteRow[]
}
