/** Comparo Wireframe — composants (namespace window.Wf). Documentation, non vérifiée. */
type Freshness = "fresh" | "old" | "expired" | "unknown";
type Trust = "high" | "medium" | "low";
type Availability = "in" | "low" | "out" | "unknown";
type PriceType = "promo" | "wholesale" | "observed";
export interface ButtonProps { variant?: "primary" | "secondary" | "ghost"; size?: "md" | "sm"; block?: boolean; disabled?: boolean; onClick?: () => void; children: React.ReactNode; }
export interface SearchBarProps { placeholder?: string; value?: string; voice?: boolean; }
export interface TextFieldProps { label: string; placeholder?: string; value?: string; suffix?: string; hint?: string; error?: string; inputMode?: string; id?: string; }
export interface PlaceholderProps { width?: number | string; height?: number | string; label?: string; }
export interface PriceTagProps { amount: number; currency?: string; unitPrice?: number; unit?: string; priceType?: PriceType; wasAmount?: number; freshness?: Freshness; size?: "md" | "lg"; variant?: "tag"; }
export interface FreshnessBadgeProps { level?: Freshness; age?: string; }
export interface TrustBadgeProps { level?: Trust; source?: string; onClick?: () => void; }
export interface AvailabilityChipProps { status?: Availability; }
export interface OfferRowProps { vendor: string; zone?: string; distance?: string; date?: string; amount: number; unitPrice?: number; unit?: string; priceType?: PriceType; freshness?: Freshness; age?: string; trust?: Trust; availability?: Availability; best?: boolean; sponsored?: boolean; }
export interface ProductCardProps { name: string; brand?: string; format?: string; fromAmount: number; offers?: number; layout?: "grid" | "row"; sponsored?: boolean; }
export interface BannerProps { tone?: "offline" | "info" | "warning" | "success"; title?: string; children?: React.ReactNode; action?: string; onAction?: () => void; }
export interface TabsProps { items: string[]; value?: number; onChange?: (i: number) => void; }
export interface AppBarProps { title: string; back?: boolean; actions?: string[]; }
export interface BottomNavProps { items?: string[]; value?: number; }
export interface EmptyStateProps { title: string; children?: React.ReactNode; action?: string; onAction?: () => void; }
export interface GaugeProps { kind?: "freshness" | "trust"; level?: Freshness | Trust; label?: string; children?: React.ReactNode; }
export interface AnnotationProps { n?: number | string; children: React.ReactNode; }

export interface PriceLineOffer { price: number; vendor: string; id?: string; }
/** Corde à prix : offres accrochées à une ficelle, placées selon leur prix ; la moins chère en citron. */
export interface PriceLineProps { offers: PriceLineOffer[]; size?: "sm" | "lg"; onSelect?: (offer: PriceLineOffer) => void; state?: "loading"; offline?: boolean; }
/** Ligne de preuve : âge du prix, source et un verdict en un mot. */
export interface ProofLineProps { age?: string; source?: "vendor" | "field"; level?: Trust; state?: "loading"; offline?: boolean; }
/** Picto produit plat avec repère de marque. */
export interface PictoProps { kind: "riz" | "huile" | "sucre" | "lait" | "sardine" | "eau" | "savon" | "conserve"; brand?: string; size?: "md" | "lg"; state?: "loading"; }
export interface SlateRow { label: string; value?: number | string; missing?: string; selected?: boolean; onClick?: () => void; }
/** Ardoise du marché. */
export interface SlateProps { title?: string; meta?: string; rows: SlateRow[]; footer?: string; state?: "loading" | "error"; onRetry?: () => void; emptyText?: string; /** date du cache, ex. « prix du 3 nov., 18:40 » */ offline?: string; }
/** Carte « Ma liste de la semaine ». count = 0 → invitation à commencer. */
export interface ListSummaryProps { count: number; best?: number; save?: number; onOpen?: () => void; onStart?: () => void; state?: "loading"; /** date du cache */ offline?: string; }
