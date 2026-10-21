// Types for @calloop/agent-react.
import type { ReactNode, ReactElement, AudioHTMLAttributes } from 'react';
import type {
    CalloopAgent, Call, Monitor, ConnectOptions, Session, Availability, CallStateName, CallData, Customer,
    QueueSnapshot, TeamMember, BoardCall, MonitorMode,
} from '@calloop/agent-sdk';

/** 'closed': Calloop ended the connection and won't reconnect it (e.g. a revoked signing key); error says why. */
export type ConnectionStatus = 'connecting' | 'ready' | 'reconnecting' | 'closed' | 'error';

export type CalloopProviderProps = Partial<ConnectOptions> & {
    children?: ReactNode;
    /** An already connected agent, instead of connecting here. */
    agent?: CalloopAgent;
    /** Replaces the SDK's connect (tests). */
    connect?: (opts: ConnectOptions) => Promise<CalloopAgent>;
};

/** Connects once and shares the agent with every hook below it. */
export function CalloopProvider(props: CalloopProviderProps): ReactElement;

export function useCalloop(): { agent: CalloopAgent | null; status: ConnectionStatus; error: Error | null };

export function useAgent(): {
    agent: CalloopAgent | null;
    me: Session['agent'] | null;
    tenant: Session['tenant'] | null;
    availability: Availability | null;
    isSupervisor: boolean;
    setAvailability(value: 'AVAILABLE' | 'OFFLINE', opts?: { agentId?: number | string }): void;
};

/** This agent's calls. */
export function useCalls(): Call[];
/** Calls ringing for this agent. */
export function useIncomingCalls(): Call[];
/** The call this agent is on (connecting, active or dialing). */
export function useActiveCall(): Call | null;

export function useCall(call: Call | null | undefined): {
    call: Call | null | undefined;
    state: CallStateName | null;
    data: CallData | null;
    customer: Customer | null;
    remoteStream: MediaStream | null;
    endReason: string | null;
    muted: boolean;
    /** The last key the customer pressed during the call. */
    lastDigit: string | null;
    accept(opts?: { stream?: MediaStream }): Promise<void> | undefined;
    decline(): void;
    hangup(): void;
    mute(value?: boolean): void;
    transfer(target: { agentId: number | string } | { queueId: number | string }): void;
    setPrivate(active: boolean): void;
    switchHere(opts?: { stream?: MediaStream }): Promise<void> | undefined;
};

export function useQueues(): QueueSnapshot[];
export function useTeam(): TeamMember[];

/** Supervisors: the tenant's live calls. */
export function useBoard(): BoardCall[];

/** Supervisors: monitoring one call. Stops on unmount or when callId changes. */
export function useMonitor(callId: number | string | null | undefined): {
    monitor: Monitor | null;
    state: 'idle' | 'connecting' | 'active';
    mode: MonitorMode | null;
    /** The call as the supervisor hears it: the customer and the agent, mixed. */
    stream: MediaStream | null;
    /** start() rejected, the monitor failed or was refused, or a setMode() was refused (code: Calloop's error code). */
    error: (Error & { code?: string }) | null;
    start(opts?: { stream?: MediaStream }): Promise<Monitor | null>;
    stop(): void;
    setMode(mode: MonitorMode): void;
    mute(value?: boolean): void;
};

/** Plays a MediaStream in an <audio> element. */
export function RemoteAudio(props: { stream: MediaStream | null | undefined; muted?: boolean } & AudioHTMLAttributes<HTMLAudioElement>): ReactElement;
