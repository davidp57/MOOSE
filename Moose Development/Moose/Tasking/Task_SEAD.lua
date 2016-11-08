--- This module contains the TASK_SEAD classes.
-- 
-- 1) @{#TASK_SEAD} class, extends @{Task#TASK_BASE}
-- =================================================
-- The @{#TASK_SEAD} class defines a SEAD task for a @{Set} of Target Units, located at a Target Zone, 
-- based on the tasking capabilities defined in @{Task#TASK_BASE}.
-- The TASK_SEAD is implemented using a @{Statemachine#STATEMACHINE_TASK}, and has the following statuses:
-- 
--   * **None**: Start of the process
--   * **Planned**: The SEAD task is planned. Upon Planned, the sub-process @{Process_Assign#PROCESS_ASSIGN_ACCEPT} is started to accept the task.
--   * **Assigned**: The SEAD task is assigned to a @{Group#GROUP}. Upon Assigned, the sub-process @{Process_Route#PROCESS_ROUTE} is started to route the active Units in the Group to the attack zone.
--   * **Success**: The SEAD task is successfully completed. Upon Success, the sub-process @{Process_SEAD#PROCESS_SEAD} is started to follow-up successful SEADing of the targets assigned in the task.
--   * **Failed**: The SEAD task has failed. This will happen if the player exists the task early, without communicating a possible cancellation to HQ.
-- 
-- ===
-- 
-- ### Authors: FlightControl - Design and Programming
-- 
-- @module Task_SEAD



do -- TASK_SEAD

  --- The TASK_SEAD class
  -- @type TASK_SEAD
  -- @field Set#SET_UNIT TargetSetUnit
  -- @extends Tasking.Task#TASK_BASE
  TASK_SEAD = {
    ClassName = "TASK_SEAD",
  }
  
  --- Instantiates a new TASK_SEAD.
  -- @param #TASK_SEAD self
  -- @param Mission#MISSION Mission
  -- @param Set#SET_GROUP SetGroup The set of groups for which the Task can be assigned.
  -- @param #string TaskName The name of the Task.
  -- @param Set#SET_UNIT UnitSetTargets
  -- @param Zone#ZONE_BASE TargetZone
  -- @return #TASK_SEAD self
  function TASK_SEAD:New( Mission, SetGroup, TaskName, TargetSetUnit, TargetZone )
    local self = BASE:Inherit( self, TASK_BASE:New( Mission, SetGroup, TaskName, "SEAD", "A2G" ) ) -- Tasking.Task_SEAD#TASK_SEAD
    self:F()
  
    self.TargetSetUnit = TargetSetUnit
    self.TargetZone = TargetZone
    
    self:SetProcessTemplate( "ASSIGN", PROCESS_ASSIGN_ACCEPT:New( self.TaskBriefing ) )
    self:SetProcessTemplate( "ROUTE", PROCESS_ROUTE_ZONE:New( self.TargetZone ) )
    self:SetProcessTemplate( "ACCOUNT", PROCESS_ACCOUNT_DEADS:New( self.TargetSetUnit, "SEAD" ) )
    self:SetProcessTemplate( "SMOKE", PROCESS_SMOKE_TARGETS_ZONE:New( self.TargetSetUnit, self.TargetZone ) )
    
    _EVENTDISPATCHER:OnPlayerLeaveUnit( self._EventPlayerLeaveUnit, self )
    _EVENTDISPATCHER:OnDead( self._EventDead, self )
    _EVENTDISPATCHER:OnCrash( self._EventDead, self )
    _EVENTDISPATCHER:OnPilotDead( self._EventDead, self )
  
    return self
  end

  --- Removes a TASK_SEAD.
  -- @param #TASK_SEAD self
  -- @return #nil
  function TASK_SEAD:CleanUp()

    self:GetParent(self):CleanUp()
    
    return nil
  end
  
  
  
  --- Assign the @{Task} to a @{Unit}.
  -- @param #TASK_SEAD self
  -- @param Unit#UNIT TaskUnit
  -- @return #TASK_SEAD self
  function TASK_SEAD:AssignToUnit( TaskUnit )
    self:F( TaskUnit:GetName() )
    
    local ProcessAssign = self:AssignProcess( TaskUnit, "ASSIGN" )
    local ProcessRoute = self:AssignProcess( TaskUnit, "ROUTE" )
    local ProcessAccount = self:AssignProcess( TaskUnit, "ACCOUNT" )
    local ProcessSmoke = self:AssignProcess( TaskUnit, "SMOKE" )
    
    local FSMT = {
        initial = 'None',
        events = {
          { name = 'Next',    from = 'None',          to = 'Planned' },
          { name = 'Next',    from = 'Planned',       to = 'Assigned' },
          { name = 'Reject',  from = 'Planned',       to = 'Rejected' }, 
          { name = 'Next',    from = 'Assigned',      to = 'Success' },
          { name = 'Fail',    from = 'Assigned',      to = 'Failed' }, 
          { name = 'Fail',    from = 'Arrived',       to = 'Failed' }     
        },
        subs = {
          Assign = {  onstateparent = 'Planned',          oneventparent = 'Next',         fsm = ProcessAssign,        event = 'Start',      returnevents = { 'Next', 'Reject' } },
          Route = {   onstateparent = 'Assigned',         oneventparent = 'Next',         fsm = ProcessRoute,         event = 'Start'       },
          Sead = {    onstateparent = 'Assigned',         oneventparent = 'Next',         fsm = ProcessAccount,       event = 'Start',      returnevents = { 'Next' } },
          Smoke = {   onstateparent = 'Assigned',         oneventparent = 'Next',         fsm = ProcessSmoke,         event = 'Start',      }
        }
      }
    
    local Process = self:AddStateMachine( TaskUnit, STATEMACHINE_TASK:New( FSMT, self, TaskUnit ) )

    Process:Next()
  
    return self
  end
  
  --- StateMachine callback function for a TASK
  -- @param #TASK_SEAD self
  -- @param StateMachine#STATEMACHINE_TASK Fsm
  -- @param #string Event
  -- @param #string From
  -- @param #string To
  -- @param Event#EVENTDATA Event
  function TASK_SEAD:onafterNext( Fsm, Event, From, To )
  
    self:SetState( self, "State", To )
  
  end
  
  --- @param #TASK_SEAD self
  function TASK_SEAD:GetPlannedMenuText()
    return self:GetStateString() .. " - " .. self:GetTaskName() .. " ( " .. self.TargetSetUnit:GetUnitTypesText() .. " )"
  end
  
end  
